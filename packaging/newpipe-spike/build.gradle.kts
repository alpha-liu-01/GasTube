plugins {
    kotlin("jvm") version "2.1.10"
}

repositories {
    mavenCentral()
    maven { url = uri("https://jitpack.io") }
}

dependencies {
    // v0.26.5 leaves comment avatars empty. e1853be2b0 reads avatarThumbnailUrl.
    implementation("com.github.teamnewpipe:newpipeextractor:e1853be2b0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.code.gson:gson:2.11.0")
}

kotlin {
    jvmToolchain(17)
}

tasks.jar {
    archiveFileName.set("newpipe-spike.jar")
    manifest {
        attributes["Main-Class"] = "com.fazilvk.fluxtube.spike.MainKt"
    }
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    val runtime = configurations.runtimeClasspath.get()
    from(runtime.map { if (it.isDirectory) it else zipTree(it) })
}
