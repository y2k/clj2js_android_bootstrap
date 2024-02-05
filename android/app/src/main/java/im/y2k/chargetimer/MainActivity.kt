package im.y2k.chargetimer

import android.app.Activity
import android.media.AudioManager
import android.os.Bundle
import android.webkit.WebView

class MainActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val webView = WebView(this).also(::setContentView)

        main(this@MainActivity, webView)
    }
}