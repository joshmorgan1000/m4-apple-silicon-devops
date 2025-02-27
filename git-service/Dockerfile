FROM gitea/gitea:1.22.5

USER root

ENV \
  GITEA__database__DB_TYPE=sqlite3 \
  GITEA__database__PATH=/data/gitea/gitea.db \
  GITEA__security__INSTALL_LOCK=true \
  GITEA__security__SECRET_KEY=supersecretkey \
  GITEA__service__DISABLE_REGISTRATION=true \
  GITEA__service__REQUIRE_SIGNIN_VIEW=false \
  GITEA__service__ALLOW_ANON_GIT_PULL=true \
  GITEA__service__ALLOW_ANON_GIT_PUSH=true \
  GITEA__server__DOMAIN=localhost \
  GITEA__server__HTTP_PORT=3000 \
  GITEA__server__ROOT_URL=http://localhost:3000/ \
  GITEA__admin__USERNAME=admin \
  GITEA__admin__PASSWORD=admin123 \
  GITEA__admin__EMAIL=admin@example.com

EXPOSE 3000 22