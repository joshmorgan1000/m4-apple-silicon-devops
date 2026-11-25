# Devops Configuration

Designed to run on an Apple Silicon device (preferably a beefy one).

Sets up git, argocd, a local kubernetes cluster, and jenkins... with some extra dev pods.

## Prerequisites

- Docker Desktop (running Kubernetes)
- kubectl
- argocd
- git (command line client)
- envsubst (provided by GNU gettext)

If you're feeling lucky just run the one-shot-install.sh script to set up the devops environment.

Or you might take a look at it first.

The installer's third argument selects the storage directory for the registry, Git service, and Jenkins; no machine-specific storage directory is committed.

For manual deployment, set `DEVOPS_STORAGE_PATH` and render the registry and Git manifests with `envsubst '${DEVOPS_STORAGE_PATH}'` before applying them; Jenkins requires an explicit `rootStoragePath` Helm value.
