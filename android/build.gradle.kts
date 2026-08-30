allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Repozytorium Android SDK nie wydaje juz pakietu "platforms;android-37" — API 37 istnieje wylacznie
// w wariantach z wersja poboczna (37.0, 37.1, ...). Wtyczka deklarujaca samo compileSdk = 37 kaze wiec
// AGP szukac nieistniejacego celu "android-37" i build pada. Domykamy takie moduly na wersji pobocznej 0.
subprojects {
    afterEvaluate {
        val android = extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?: return@afterEvaluate
        val compileSdk = android.compileSdk
        if (compileSdk != null && compileSdk >= 37 && android.compileSdkMinor == null) {
            android.compileSdkMinor = 0
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
