buildscript {
    // Define kotlin_version using the Kotlin DSL extra property delegate
    val kotlin_version by extra { "2.1.0" } // Update to 2.1.0 or higher (e.g., "2.2.0")
    
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")
        // Reference the property directly
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version") 
    }
}

// The rest of the file is fine and should remain as is:
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}