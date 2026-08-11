import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

// 修复第三方插件（quickjs_engine 等）内部 JVM 目标不一致问题：
// 这类插件的 build.gradle 未设置 kotlin jvmTarget，其 Java 默认 1.8（compileOptions 已被 Gradle finalized 无法改），
// 而 Kotlin 任务默认跟随项目 KGP 2.x 升到 21，导致
// "Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks"。
// 解法：只把插件模块的 Kotlin jvmTarget 降到 1.8 与 Java 对齐（不动 app 模块，否则会与 app 的 Java 17 冲突）。
// 用 plugins.withId 钩子（插件 apply 时触发），避免使用已提前 evaluate 子项目的 afterEvaluate。
subprojects {
    plugins.withId("kotlin-android") {
        if (project.name == "quickjs_engine") {
            tasks.withType<KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(JvmTarget.JVM_1_8)
            }
        }
    }
    plugins.withId("org.jetbrains.kotlin.android") {
        if (project.name == "quickjs_engine") {
            tasks.withType<KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(JvmTarget.JVM_1_8)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
