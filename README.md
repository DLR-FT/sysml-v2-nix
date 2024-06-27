# How to run?

```
nix build
initdb -D postgres_data
postgres -D postgres_data --single
result/bin/sysml-v2-api-services -Dpidfile.path=$PWD/play.pid
```
