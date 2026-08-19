There is no oci chart released for the sops operator. As there are strong correlations between the operator version and
the kubernetes cluster version, an automatic update solution is omitted for now. Download the new chart using:

```
helm pull sops-secrets-operator \
  --repo https://isindir.github.io/sops-secrets-operator/ \
  --version <VERSION>
```
