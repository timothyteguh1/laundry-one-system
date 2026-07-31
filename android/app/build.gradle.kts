import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.laundry_one" // [UPDATE]: Ganti dari com.example
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        // [UPDATE]: Jangan gunakan com.example, pakai ID aplikasi pelanggan sebagai default
        applicationId = "com.example.laundry_one"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // ==========================================================
    // KONFIGURASI FLAVORS UNTUK 2 APLIKASI
    // ==========================================================
    flavorDimensions += "app"

    productFlavors {
        create("customer") {
            dimension = "app"
            applicationId = "com.laundryone.customer"
            resValue("string", "app_name", "Laundry One")
        }
        create("cashier") {
            dimension = "app"
            applicationId = "com.laundryone.cashier"
            resValue("string", "app_name", "Laundry Kasir")
        }
    }
    // ==========================================================

    signingConfigs {
        create("release") {
            // Memastikan ini tidak error jika key.properties belum ada saat mode debug
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Hanya gunakan signing config jika file properties ada
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Optimasi Rilis: Membuang kode tak terpakai agar aplikasi pelanggan lebih ringan
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}