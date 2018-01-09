### Como funciona

Cria ambiente para uso do GLPI na versão desejada ou inicializa base existente

### Como usar

Edit o arquivo docker-compose.yml para a versão do GLPI desejada

```sh
git clone https://github.com/abelmferreira/me-docker-compose-glpi
chown -R www-data.www-data html/
docker-compose up -d
```

