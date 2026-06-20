pluginManagement {
    fun flutterSdkPathFromPath(): String? {
        val path = System.getenv("PATH") ?: return null
        val executableNames =
            if (System.getProperty("os.name").lowercase().contains("windows")) {
                val extensions = System.getenv("PATHEXT")
                    ?.split(";")
                    ?.filter { it.isNotBlank() }
                    ?: listOf(".exe", ".bat", ".cmd")
                extensions.map { "flutter$it" } + "flutter"
            } else {
                listOf("flutter")
            }

        return path.split(File.pathSeparator)
            .asSequence()
            .filter { it.isNotBlank() }
            .flatMap { directory ->
                executableNames.asSequence().map { executable -> file("$directory/$executable") }
            }
            .firstOrNull { it.isFile && it.canExecute() }
            ?.canonicalFile
            ?.parentFile
            ?.parentFile
            ?.absolutePath
    }

    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localProperties = file("local.properties")
            if (localProperties.isFile) {
                localProperties.inputStream().use { properties.load(it) }
            }

            val flutterSdkPath = flutterSdkPathFromPath()
                ?: properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter command not found in PATH and flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
