class Bazel < Formula
  desc "Google's own build tool"
  homepage "https://bazel.build/"
  url "https://github.com/bazelbuild/bazel/releases/download/3.0.0/bazel-3.0.0-dist.zip"
  sha256 "530f5132e0a50da7ebb0ed08d9b6f1ddfd0d7d9b5d0beb2df5d687a4c8daf6b3"

  bottle do
    cellar :any_skip_relocation
    sha256 "efcb511e145934583bd890874f7f46e4d07755e07d160e7345633bd303caf391" => :catalina
    sha256 "087ce9d26b67f254f9a4cdca9eb6319e75aa857b3cf5dbfb6b7e50144fea8631" => :mojave
    sha256 "54790f257823b8e226a718cd323301340714223b30c31f912c77b3dbdb4cea31" => :high_sierra
  end

  depends_on "python@3.8" => :build
  depends_on :java => "1.8"
  depends_on :macos => :yosemite

  uses_from_macos "zip"

  def install
    ENV["EMBED_LABEL"] = "#{version}-homebrew"
    # Force Bazel ./compile.sh to put its temporary files in the buildpath
    ENV["BAZEL_WRKDIR"] = buildpath/"work"

    (buildpath/"sources").install buildpath.children

    cd "sources" do
      system "./compile.sh"
      system "./output/bazel",
             "--output_user_root",
             buildpath/"output_user_root",
             "build",
             "--host_java_toolchain=@bazel_tools//tools/jdk:toolchain_hostjdk8",
             "--java_toolchain=@bazel_tools//tools/jdk:toolchain_hostjdk8",
             "--host_javabase=@bazel_tools//tools/jdk:jdk",
             "--javabase=@bazel_tools//tools/jdk:jdk",
             "scripts:bash_completion"

      bin.install "scripts/packages/bazel.sh" => "bazel"
      ln_s libexec/"bin/bazel-real", bin/"bazel-#{version}"
      (libexec/"bin").install "output/bazel" => "bazel-real"
      bin.env_script_all_files(libexec/"bin", Language::Java.java_home_env("1.8"))

      bash_completion.install "bazel-bin/scripts/bazel-complete.bash"
      zsh_completion.install "scripts/zsh_completion/_bazel"

      prefix.install_metafiles
    end
  end

  test do
    touch testpath/"WORKSPACE"

    (testpath/"ProjectRunner.java").write <<~EOS
      public class ProjectRunner {
        public static void main(String args[]) {
          System.out.println("Hi!");
        }
      }
    EOS

    (testpath/"BUILD").write <<~EOS
      java_binary(
        name = "bazel-test",
        srcs = glob(["*.java"]),
        main_class = "ProjectRunner",
      )
    EOS

    system bin/"bazel",
           "build",
           "--host_java_toolchain=@bazel_tools//tools/jdk:toolchain_hostjdk8",
           "--java_toolchain=@bazel_tools//tools/jdk:toolchain_hostjdk8",
           "--host_javabase=@bazel_tools//tools/jdk:jdk",
           "--javabase=@bazel_tools//tools/jdk:jdk",
           "//:bazel-test"
    assert_equal "Hi!\n", pipe_output("bazel-bin/bazel-test")

    # Verify that `bazel` invokes Bazel's wrapper script, which delegates to
    # project-specific `tools/bazel` if present. Invoking `bazel-VERSION`
    # bypasses this behavior.
    (testpath/"tools"/"bazel").write <<~EOS
      #!/bin/bash
      echo "stub-wrapper"
      exit 1
    EOS
    (testpath/"tools/bazel").chmod 0755

    assert_equal "stub-wrapper\n", shell_output("#{bin}/bazel --version", 1)
    assert_equal "bazel #{version}-homebrew\n", shell_output("#{bin}/bazel-#{version} --version")
  end
end
