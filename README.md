## Why

* We want to dev fast
* We want CI without spending months thinking about it
* We want flexibility
* We want to share (and be consistent)

#

## K8s

Helm vs Manifests
: Kubernetes manifests are much more reproducible than Helm charts. However, the convenience of managing dependencies with Helm can not be overlooked. To meet both of these goals, we can generate manifests via `helm template` and store them in our repo. This process is made simple by generating a set of manifests from a bazel definition of helm charts.

: In addition to increased reproducability of builds, the `kustomize` workflow is also more natural with manifests than helm. It allows a unified way to deal with different environments, even for dependencies (if that is needed).

## Alternatives Considered

Earthly
: CI definitions that look like Makefiles and Dockerfiles had a baby

Skaffold
: Has some issues with dependencies that rely on CRDs. Value is watching/auto-tagging images within manifests. Can accomplish this by wiring in the built image digests.

Gitlab Local Runners
: Can have a single place to define rules, and run that locally for dev. Some things became awkward:

  * Current tools want to do a fresh checkout, that mean we need to commit to test (easy to overcome by a tmp commit)
  * No DAG support, so if you need to run things with dependencies, you need to calculate them yourself (or write a wrapper script to parse/calculate)
  * End up with indirection, so tinkering/leaving things up is slightly unnatural

## Notes

### Gitlab integration

#### Workspace Config

When running under Gitlab, you need to make sure to have a `output_base` that lives within the repository workspace directory. Otherwise, artifacts will fail to be recognized, even if you copy them out. We handle that here by defining it in `.bazelrc` file.

#### Test Reporting

Bazel is fairly nice in that it support Junit Reporting out of the box. Those reports are found under `bazel-testlogs`. However, tests need to use GO_TEST_WRAP_TEST=1 to make sure the output reports ran tests, and not just failed ones (the counts).

#### Caching

Caching is important for each stage in your CI system. Gitlab can cache by simply using the `output_base` as described above. This is the naive approach, and while useful to start, it can take some time to copy files off and upload them into Gitlab. Bazel supports its own remote cache which is more performant, and allows devs and CI to share caching. We can take it a step further and give devs read-only rights to the cache.

https://docs.bazel.build/versions/main/remote-caching.html#bazel-remote

**Note:** It is very important to pay attention and pin your dependencies (shas, digests, etc). Otherwise, it will break the dependency tree and it will not be able to use a cache for all derivate dependencies. There are good debug steps for analyzing the cache's value (https://docs.bazel.build/versions/4.2.0/remote-execution-caching-debug.html#checking-your-cache-hit-rate)