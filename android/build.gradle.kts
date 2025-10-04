// Register plugin dependencies for the project
plugins {
    // Standard plugins: Remove explicit versions to avoid conflict
    id("com.android.application") apply false 
    id("kotlin-android") apply false 
    
    // Firebase plugin: Keep version specified
    id("com.google.gms.google-services") version "4.4.1" apply false // Use the latest stable version
}

allprojects {
    repositories {
        google()
        mavenCentral()
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