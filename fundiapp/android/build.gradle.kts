allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Intercept project evaluation before plugins load their build.gradle files
    subprojects {
        project.beforeEvaluate {
            if (project.name == "flutter_inappwebview_android") {
                val buildGradleFile = project.file("build.gradle")
                if (buildGradleFile.exists()) {
                    val content = buildGradleFile.readText()
                    if (content.contains("proguard-android.txt")) {
                        val updatedContent = content.replace("proguard-android.txt", "proguard-android-optimize.txt")
                        buildGradleFile.writeText(updatedContent)
                    }
                }
            }
        }

        afterEvaluate {
            extensions.findByName("android")?.let { android ->
                val ext = android as com.android.build.gradle.BaseExtension
                ext.compileSdkVersion(36)
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}