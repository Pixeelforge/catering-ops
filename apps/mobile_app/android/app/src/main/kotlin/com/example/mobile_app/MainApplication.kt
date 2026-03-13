package com.example.mobile_app

import android.app.Application
import com.onesignal.OneSignal
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        // OneSignal Initialization
        OneSignal.initWithContext(this, "e03d985c-4050-41d6-88fd-092232fa325b")

        // Request notification permission on first run
        CoroutineScope(Dispatchers.Main).launch {
            OneSignal.Notifications.requestPermission(true)
        }
    }
}
