#!/bin/bash

# 1. Make sure the first and second arguments are there (used for passwords)
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <jenkins_admin_password> <argocd_admin_password> <local_storage_path>"
    exit 1
fi
# Check if $3 is a valid directory
if [ ! -d "$3" ]; then
    echo "ERROR: $3 is not a valid directory."
    exit 1
fi
mkdir -p $3/docker
mkdir -p $3/git-service
mkdir -p $3/jenkins.arm64
mkdir -p $3/jenkins.x86
mkdir -p $3/shared

# 2. Deploy Local Registry and create storage directories
echo "Deploying Local Docker Registry..."
cd registry
kubectl apply -f docker-registry-config.yaml
cd ..

# 3. Deploy The Local Git Service
echo "Deploying Local Git Service..."
cd git-service
docker build -t localhost:30050/git-service:latest .
docker push localhost:30050/git-service:latest
kubectl apply -f git-pv.yaml
kubectl apply -f git-deployment.yaml
kubectl apply -f git-service.yaml
# Wait for the service to be ready
while [ "$(kubectl get pods -o jsonpath='{.items[0].status.containerStatuses[0].ready}')" != "true" ]; do
    sleep 1
done
NEW_PASSWORD="$1"
# Get the first running Gitea pod dynamically
GITEA_POD=$(kubectl get pods -o jsonpath="{.items[0].metadata.name}")
if [ -z "$GITEA_POD" ]; then
    echo "ERROR: No Gitea pod found in namespace $NAMESPACE."
    exit 1
fi
# Generate bcrypt hash of the password dynamically
BCRYPT_HASH=$(kubectl exec -n $NAMESPACE $GITEA_POD -- \
    htpasswd -bnBC 10 "" "$1" | tr -d ':\n'
if [ -z "$BCRYPT_HASH" ]; then
    echo "ERROR: Failed to generate bcrypt hash for git password."
    exit 1
fi
kubectl exec -n $NAMESPACE $GITEA_POD -- sqlite3 /data/gitea/gitea.db \
    "UPDATE user SET password = '$BCRYPT_HASH' WHERE name = 'admin';"
cd ..

# 4. Deploy argocd
echo "Deploying ArgoCD..."
cd argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd --type='merge' -p '{
  "spec": {
    "type": "LoadBalancer",
    "ports": [
      {
        "name": "http",
        "port": 30081,
        "protocol": "TCP",
        "targetPort": 8080
      }
    ]
  }
}'
ARGOCD_ADMIN_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode)
argocd login localhost:30081 --username admin --password $ARGOCD_ADMIN_PASSWORD
argocd account update-password --current-password $ARGOCD_ADMIN_PASSWORD --new-password $2
cd ..
# Wait until all the pods are ready
while [ "$(kubectl get pods -n argocd -o jsonpath='{.items[*].status.containerStatuses[*].ready}')" != "true true true true true true true" ]; do
    sleep 1
done

# 5. Deploy Jenkins
echo "Deploying Jenkins..."
cd jenkins
docker build -t localhost:30050/jenkins-x86:latest . -f Dockerfile.x86
docker push localhost:30050/jenkins-x86:latest
docker build -t localhost:30050/jenkins-arm64:latest . -f Dockerfile.arm64
docker push localhost:30050/jenkins-arm64:latest
curl -u "admin:$1" \
     -H "Content-Type: application/json" \
     -d '{ "name": "helm", "private": false }' \
     http://localhost:30080/api/v1/user/repos
cd ..
git clone http://localhost:30080/admin/helm.git
cd helm
mkdir jenkins
cp -R ../jenkins/helm jenkins/ 
git add .
git commit -m "Add Jenkins Helm Chart"
git push
cd ..
rm -rf helm
argocd login localhost:30081 --username admin --password "$2" --insecure
argocd repo add http://git-svc.default.svc.cluster.local:3000/admin/helm.git
kubectl create namespace jenkins
argocd app create jenkins \
  --repo http://git-svc.default.svc.cluster.local:3000/admin/helm.git \
  --path jenkins/helm \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace jenkins \
  --revision main \
  --helm-set jenkinsMaster.enabled=true \
  --helm-set jenkinsAgent.enabled=false \
  --helm-set rootStoragePath=$3 \
  --sync-policy automated
# Wait until the $3/jenkins.x86/secret.key file is created
while [ ! -f "$3/jenkins.x86/secret.key" ]; do
    sleep 1
done
# Get the secret key from the file
JENKINS_SECRET_KEY=$(cat $3/jenkins.x86/secret.key)

echo "One-shot installation complete!"
echo "Local Docker Registry: localhost:30050"
echo "Local Git Service: http://localhost:30080"
echo "ArgoCD URL: http://localhost:30081"
echo "Jenkins URL: http://localhost:30080"
echo " "
echo "You must login to Jenkins to complete the setup. The initial password is:"
echo $JENKINS_SECRET_KEY
echo " "