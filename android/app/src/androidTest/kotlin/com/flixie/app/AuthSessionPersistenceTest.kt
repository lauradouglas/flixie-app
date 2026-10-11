package com.flixie.app

import android.content.Context
import androidx.test.platform.app.InstrumentationRegistry
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.auth.FirebaseAuth
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.TimeUnit

/** Run seed, kill the app process, then restore, without reinstalling/clearing data.
 * A named demo Firebase app and Auth emulator isolate this from real identities.
 */
class AuthSessionPersistenceTest {
    @Test fun sessionSurvivesProcessDeath() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val phase = InstrumentationRegistry.getArguments().getString("authPhase")
        require(phase in listOf("seed", "restore", "logout", "signedOut"))
        val app = FirebaseApp.initializeApp(context, FirebaseOptions.Builder()
            .setApplicationId("1:123456789:android:0123456789abcdef")
            .setApiKey("AIzaSy000000000000000000000000000000000")
            .setProjectId("demo-flixie-session")
            .build(), "flixie-session-fixture")!!
        val auth = FirebaseAuth.getInstance(app)
        auth.useEmulator("10.0.2.2", 9099)
        val prefs = context.getSharedPreferences("flixie-session-fixture", Context.MODE_PRIVATE)
        when (phase) {
            "seed" -> {
                auth.signOut()
                val user = Tasks.await(auth.signInAnonymously(), 20, TimeUnit.SECONDS).user!!
                assertTrue(prefs.edit().putString("uid", user.uid).commit())
            }
            "restore" -> {
                val expected = prefs.getString("uid", null)
                assertNotNull("Run seed in a separate process first", expected)
                assertEquals("Cold start must restore the same Firebase user", expected, auth.currentUser?.uid)
                assertNotNull(Tasks.await(auth.currentUser!!.getIdToken(true), 20, TimeUnit.SECONDS).token)
            }
            "logout" -> {
                auth.signOut()
                assertNull(auth.currentUser)
                assertTrue(prefs.edit().clear().commit())
            }
            "signedOut" -> {
                assertNull("Explicit logout must survive a cold start", auth.currentUser)
                assertNull(prefs.getString("uid", null))
            }
        }
        app.delete()
    }
}
