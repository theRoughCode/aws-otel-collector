### Steps:
1. Build the reverse-proxy container and push the image:
```
docker build -t kohrapha/reverse-proxy .
docker push kohrapha/reverse-proxy`
```
2. Configure `config.yaml` with `sample-config.yml`.
2. Build and push AOC image:
```
make docker-build
make docker-push
```
3. Upload task definition (`ecs-nginx-sidecar.json`) to ECS.
