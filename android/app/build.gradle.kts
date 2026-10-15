import java.util.Properties
import javax.inject.Inject

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Release signing comes from keystore.properties (not in git), see android/README.md.
val keystoreProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "nl.petervanmanen.divemalta"
    compileSdk = 37

    defaultConfig {
        applicationId = "nl.petervanmanen.divemalta"
        minSdk = 29
        targetSdk = 37
        versionCode = (project.findProperty("versionCode") as String?)?.toInt() ?: 1
        versionName = (project.findProperty("versionName") as String?) ?: "1.0"
    }

    signingConfigs {
        if (keystoreProps.isNotEmpty()) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("release")
        }
    }

    buildFeatures {
        compose = true
    }

    androidResources {
        // Keep the map tiles and depth grid uncompressed so they copy quickly on first start.
        noCompress += listOf("pmtiles", "bin", "pbf")
    }
}

// The app bundles shared/data as assets/data, like the iOS app bundles it as data/.
abstract class CopySharedData : DefaultTask() {
    @get:InputDirectory abstract val source: DirectoryProperty
    @get:OutputDirectory abstract val output: DirectoryProperty

    @get:Inject abstract val fs: FileSystemOperations

    @TaskAction
    fun copy() {
        fs.sync {
            from(source)
            into(output.dir("data"))
        }
    }
}

val copySharedData = tasks.register<CopySharedData>("copySharedData") {
    source.set(rootProject.layout.projectDirectory.dir("../shared/data"))
}

androidComponents {
    onVariants { variant ->
        variant.sources.assets?.addGeneratedSourceDirectory(copySharedData, CopySharedData::output)
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.0")
    implementation("androidx.core:core-ktx:1.19.1")
    implementation("org.maplibre.gl:android-sdk:13.6.1")
}
