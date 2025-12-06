-- /qompassai/Diver/lsp/metals.lua
-- Qompass AI Metals LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://scalameta.org/metals/docs/editors/user-configuration
vim.lsp.config['metals'] = {
  cmd = {
    'metals',
  },
  filetypes = {
    'scala',
  },
  root_markers = {
    'build.sbt',
    'build.sc',
    "build.gradle",
    "pom.xml",
  },
  init_options = {
    statusBarProvider = "show-message",
    isHttpEnabled = true,
    compilerOptions = {
      snippetAutoIndent = false,
    },
  },
  settings = {
    metals = {
      javaHome = "/usr/lib/jvm/default",
      sbtScript = "/usr/bin/sbt",
      gradleScript = "/usr/bin/gradle",
      mavenScript = "/usr/bin/mvn",
      millScript = "/usr/bin/mill",
      scalafmtConfigPath = "project/.scalafmt.conf",
      scalafixConfigPath = "project/.scalafix.conf",
      excludedPackages = {
        "akka.actor.typed.javadsl",
      },
      bloopSbtAlreadyInstalled = false,
      bloopVersion = "2.0.17",
      bloopJvmProperties = {
        "-Xmx4G",
      },
      superMethodLensesEnabled = true,
      ["inlayHints.inferredTypes.enable"] = true,
      ["inlayHints.namedParameters.enable"] = true,
      ["inlayHints.byNameParameters.enable"] = true,
      ["inlayHints.implicitArguments.enable"] = true,
      ["inlayHints.implicitConversions.enable"] = true,
      ["inlayHints.typeParameters.enable"] = true,
      ["inlayHints.hintsInPatternMatch.enable"] = true,
      ["inlayHints.hintsXRayMode.enable"] = false,
      ["inlayHints.closingLabels.enable"] = true,
      enableSemanticHighlighting = true,
      enableIndentOnPaste = true,
      fallbackScalaVersion = "3.3.6",
      testUserInterface = "test explorer",
      ["javaFormat.eclipseConfigPath"] = "formatters/eclipse-formatter.xml",
      ["javaFormat.eclipseProfile"] = "GoogleStyle",
      scalaCliLauncher = "scala-cli",
      customProjectRoot = "backend/scalaProject/",
      verboseCompilation = false,
      autoImportBuild = "all",
      targetBuildTool = "sbt",
      defaultBspToBuildTool = true,
      enableBestEffort = true,
      defaultShell = "fish",
      --startMcpServer = true,
      --mcpClient = 'claude',
    },
  },
  capabilities = {
    workspace = {
      configuration = true,
    },
  },
}