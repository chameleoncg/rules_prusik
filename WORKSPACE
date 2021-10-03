workspace(name = "io_bazel_rules_prusik")

## == Workspace setup ==

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")

http_archive(
    name = "bazel_skylib",
    sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
    urls = [
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
    ],
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

# == Local Resources

local_repository(
    name = "k8s_helpers",
    path = "build/bazel/k8s_helpers",
)

## == Golang ==

http_archive(
    name = "io_bazel_rules_go",
    sha256 = "8e968b5fcea1d2d64071872b12737bbb5514524ee5f0a4f54f5920266c261acb",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.28.0/rules_go-v0.28.0.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.28.0/rules_go-v0.28.0.zip",
    ],
)

http_archive(
    name = "bazel_gazelle",
    sha256 = "62ca106be173579c0a167deb23358fdfe71ffa1e4cfdddf5582af26520f1c66f",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.23.0/bazel-gazelle-v0.23.0.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.23.0/bazel-gazelle-v0.23.0.tar.gz",
    ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")
load("//:build/bazel/go_mod_repositories.bzl", "go_mods")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "dataform",
    commit = "de1eb66e558fbd349092d9519a8d5a1edefba94f",
    remote = "https://github.com/dataform-co/dataform.git",
    shallow_since = "1584092301 +0000",
)

# gazelle:repository_macro build/bazel/go_mod_repositories.bzl%go_mods
go_mods()

go_rules_dependencies()

go_register_toolchains(version = "1.17")

gazelle_dependencies()

## == Docker ==

# release notes at https://github.com/bazelbuild/rules_docker/releases
http_archive(
    name = "io_bazel_rules_docker",
    sha256 = "5d31ad261b9582515ff52126bf53b954526547a3e26f6c25a9d64c48a31e45ac",
    strip_prefix = "rules_docker-0.18.0",
    urls = ["https://github.com/bazelbuild/rules_docker/releases/download/v0.18.0/rules_docker-v0.18.0.tar.gz"],
)

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load("@io_bazel_rules_docker//repositories:deps.bzl", container_deps = "deps")

container_deps()

load(
    "@io_bazel_rules_docker//go:image.bzl",
    _go_image_repos = "repositories",
)
load("@io_bazel_rules_docker//container:pull.bzl", "container_pull")

_go_image_repos()

# == K8s ==
http_archive(
    name = "io_bazel_rules_k8s",
    sha256 = "51f0977294699cd547e139ceff2396c32588575588678d2054da167691a227ef",
    strip_prefix = "rules_k8s-0.6",
    urls = ["https://github.com/bazelbuild/rules_k8s/archive/v0.6.tar.gz"],
)

load("@io_bazel_rules_k8s//k8s:k8s.bzl", "k8s_repositories")

k8s_repositories()

load("@io_bazel_rules_k8s//k8s:k8s_go_deps.bzl", k8s_go_deps = "deps")

k8s_go_deps()

# == Helm ==

load("//:build/bazel/helm_charts.bzl", "helm_setup")
helm_setup()
