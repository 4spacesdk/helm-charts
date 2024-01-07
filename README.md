## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```
helm repo add 4spacesdk https://4spacesdk.github.io/helm-charts
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
4spacesdk` to see the charts.

To install the kubernetes-service-orchestrator chart:

Create `values.yaml` file
> **_NOTE:_**  For a complete set of options see [link](https://github.com/4spacesdk/kubernetes-service-orchestrator/blob/main/charts/kso/values.yaml)


```
ingress:
  enabled: true
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: chart-example-tls
      hosts:
        - chart-example.local

deployment:

  # Valid values: development, production
  environment: ""

  # You need to provide a MySQL database
  database:
    host: ""
    name: ""
    user: ""
    pass: ""

  # The default url is "https://kubernetes.default.svc.cluster.local".
  # But it can be different depending on provider
  kubernetes:
    remoteClusterUrl: "https://kubernetes.default.svc.cluster.local"

  env: [ ]
#  env:
#    - name: ""
#      value: ""
```

```
helm upgrade --install kso 4spacesdk/kubernetes-service-orchestrator --values=values.yaml --namespace kso --create-namespace
```

To uninstall the chart:
```
helm delete kso
```
