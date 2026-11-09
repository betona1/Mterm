allprojects {
    repositories {
        // CI(tools/ci_prefetch_kotlin.sh)가 큰 코틀린 jar 를 ~/.m2 에 미리 넣어 둔다 — 맨 앞이어야 Central 의 504 를 피한다. 로컬에선 보통 비어 있어 무해.
        mavenLocal()
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
