load("@io_bazel_rules_k8s//k8s:object.bzl", "k8s_object")
load("@io_bazel_rules_k8s//k8s:objects.bzl", "k8s_objects")

def _envsubst(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".yaml")
    input_file = ctx.attr.template.files.to_list()[0]
    # TODO test to make sure we're getting the STABLE keys as well
    ctx.actions.run(
        executable = ctx.executable._stamper,
        inputs = [input_file, ctx.info_file, ctx.version_file],
        arguments = [input_file.path, out.path],
        tools = [ctx.executable._stamper],
        outputs = [out],
        mnemonic = "Stamp",
    )
    return [DefaultInfo(files = depset([out]))]

envsubst = rule(
    implementation = _envsubst,
    attrs = {
        "template": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "_stamper": attr.label(
            default = Label("//:stamper"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
    },
)

def _k8s_namespace_manifest_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".yaml")
    ctx.actions.write(
        output = out,
        content = "\n".join([
            "apiVersion: v1",
            "kind: Namespace",
            "metadata:",
            "   name: {}\n".format(ctx.attr.namespace),
        ]),
    )
    return [DefaultInfo(files = depset([out]))]

k8s_namespace_manifest = rule(
    implementation = _k8s_namespace_manifest_impl,
    attrs = {
        "namespace": attr.string(mandatory = True),
        "_stamper": attr.label(
            default = Label("//:stamper"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
    },
)

def k8s_namespace(name, namespace, substitutions):
    k8s_namespace_manifest(
        name = name + "-manifest",
        namespace = namespace,
        visibility = ["//visibility:private"],
    )

    k8s_object(
        name = name,
        cluster = "",
        template = ":%s-manifest" % name,
        substitutions = substitutions,
        visibility = ["//visibility:public"],
    )

def _kustomize_gen_impl(ctx):
    kustomize_manifest = ctx.actions.declare_file("kustomize_manifest.yaml")
    ctx.actions.run_shell(
        inputs = ctx.files.kustomize_base_dir,
        outputs = [kustomize_manifest],
        # kustomize doesn't work with symlinks, so we need to avoid them
        execution_requirements = {
            "no-sandbox": "1",
            "no-cache": "1",
        },
        arguments = [ctx.attr.kustomize_env_path, kustomize_manifest.path],
        progress_message = "Running kustomize to generate manifest",
        command = "kubectl kustomize $1 > $2",
    )
    return [DefaultInfo(files = depset([kustomize_manifest]))]

kustomize_gen = rule(
    implementation = _kustomize_gen_impl,
    attrs = {
        "kustomize_base_dir": attr.label_list(
            allow_files = True,
            mandatory = True,
        ),
        "kustomize_env_path": attr.string(
            mandatory = True,
        ),
    },
)

def k8s_kustomize(name, namespace, kustomize_base_dir, kustomize_env_path, images, substitutions):
    # First create the target namespace
    k8s_namespace(
        name = "deployment-namespace",
        namespace = namespace,
        substitutions = substitutions,
    )

    # Next, generate the yaml from the kustomize-ish overlay directory defintion
    kustomize_gen(
        name = "kustomize_gen",
        kustomize_base_dir = kustomize_base_dir,
        kustomize_env_path = kustomize_env_path,
    )

    # Wrap the template in an object, and wire in our images
    k8s_object(
        name = "deploy-obj",
        cluster = "",
        template = ":kustomize_gen",
        namespace = namespace,
        image_chroot = "{STABLE_DOCKER_REGISTRY}",
        images = images,
        substitutions = substitutions,
        visibility = ["//visibility:private"],
    )

    # Now combine them together
    k8s_objects(
        name = name,
        objects = [
            ":deployment-namespace",
            ":deploy-obj",
        ],
        visibility = ["//visibility:public"],
    )

def _sequence_runs(ctx):
    executable_paths = []
    runfiles = ctx.runfiles()

    # This override is to support k8s_rules. They try to detect the runfile location
    # but you can override it with this PYTHON_RUNFILES variable
    #
    # The scripts in k8s_object output ${RUNFILES}/__main__/$job$. In our case, we
    # are running within the __main__ of our current execution, so we need to set it
    # back a directory (verified with pwd in this executable)
    PYTHON_RUNFILES_DEF = "export PYTHON_RUNFILES=../\n"
    execution_dir = "/".join(ctx.build_file_path.split("/")[:-1])

    for dep in ctx.attr.deps:
        #executable_paths.append(dep.files_to_run.executable.short_path)
        executable_paths.append(execution_dir + "/" + dep.files_to_run.executable.basename)

        # collect the runfiles of the other executables so their own runfiles
        # will be available when the top-level executable runs
        runfiles = runfiles.merge(dep.default_runfiles)

    ctx.actions.write(
        output = ctx.outputs.executable,
        is_executable = True,
        content = "set -e\n" + PYTHON_RUNFILES_DEF + "\n".join(executable_paths),
    )

    return DefaultInfo(
        executable = ctx.outputs.executable,
        runfiles = runfiles,
    )

sequence_runs = rule(
    implementation = _sequence_runs,
    executable = True,
    attrs = {
        "deps": attr.label_list(),
    },
)

def _kubectl_wait(ctx):
    print_msg = "echo 'kubectl waiting on: " + ctx.attr.expression + "'\n"

    wait_template = ctx.actions.declare_file('kubectl_wait.tmpl')
    ctx.actions.write(
        output = wait_template,
        content = print_msg + "kubectl wait -n %s %s" % (ctx.attr.namespace, ctx.attr.expression),
    )

    ctx.actions.expand_template(
        output = ctx.outputs.executable,
        is_executable = True,
        template = wait_template,
        # TODO it will probably be necessary to figure out stamping here
        substitutions = ctx.attr.substitutions
    )
    return DefaultInfo(executable = ctx.outputs.executable)

kubectl_wait = rule(
    implementation = _kubectl_wait,
    executable = True,
    attrs = {
        "namespace": attr.string(
            mandatory = True,
        ),
        "expression": attr.string(
            mandatory = True,
        ),
        "substitutions": attr.string_dict(),
    },
)
