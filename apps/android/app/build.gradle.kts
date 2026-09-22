import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

// Release signing: `make android-keystore` generates the keystore and writes
// these dndsync.release.* keys into local.properties (gitignored). Without
// them, `assembleRelease` still runs but produces an unsigned APK.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

if (file("google-services.json").exists()) {
    pluginManager.apply("com.google.gms.google-services")
}

// Keeps IDE / command-line Gradle builds from failing closed with "unresolved
// reference: dndsync" when someone forgot `make proto` — mirrors the Xcode
// "Generate Proto" run-script build phase (see AGENTS.md "Before building").
// Inputs/outputs keep this UP-TO-DATE so we don't hit BSR rate limits on
// every Assemble. The script itself also skips generate when stubs are fresh.
val generateProto by tasks.registering(Exec::class) {
    val repoRoot = rootProject.projectDir.parentFile.parentFile
    workingDir = repoRoot
    commandLine("scripts/generate-proto.sh")
    inputs.dir(File(repoRoot, "proto"))
    inputs.file(File(repoRoot, "scripts/generate-proto.sh"))
    outputs.dir(File(repoRoot, "apps/android/generated"))
    outputs.dir(File(repoRoot, "apps/macos/Generated"))
    outputs.dir(File(repoRoot, "forwarder/generated"))
}

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(generateProto)
}

android {
    namespace = "com.dndsync.android"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.dndsync.android"
        minSdk = 35
        targetSdk = 35
        versionCode = 6
        versionName = "0.4.0"
    }

    signingConfigs {
        val storeFileName = localProperties.getProperty("dndsync.release.storeFile")
        val releaseKeystore = storeFileName?.let { rootProject.file(it) }
        if (releaseKeystore != null && releaseKeystore.exists()) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = localProperties.getProperty("dndsync.release.storePassword")
                keyAlias = localProperties.getProperty("dndsync.release.keyAlias")
                keyPassword = localProperties.getProperty("dndsync.release.keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfigs.findByName("release")?.let { signingConfig = it }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    sourceSets {
        getByName("main") {
            java.srcDir(rootProject.file("generated"))
            kotlin.srcDir(rootProject.file("generated"))
            assets.srcDir(rootProject.file("licenses"))
        }
        getByName("test") {
            resources.srcDir(rootProject.file("../../proto/fixtures"))
        }
    }
}

// GitHub Release asset is DNDSync-<version>.apk (versionName, no -release suffix).
android.applicationVariants.configureEach {
    if (buildType.name != "release") return@configureEach
    val releaseName = "DNDSync-$versionName.apk"
    outputs.configureEach {
        (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl)
            .outputFileName = releaseName
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.hilt.navigation.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    debugImplementation(libs.androidx.compose.ui.tooling)

    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    implementation(libs.protobuf.javalite)
    implementation(libs.protobuf.kotlin.lite)
    implementation(libs.okhttp)
    implementation(libs.tink.android)

    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)
    implementation(libs.androidx.camera.mlkit.vision)
    implementation(libs.mlkit.barcode.scanning)

    testImplementation(libs.junit)
}
