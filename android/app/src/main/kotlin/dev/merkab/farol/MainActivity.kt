package dev.merkab.farol

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Passar o Farol adiante": onde está o APK instalado, para enviar
        // a outro celular sem internet.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "farol/apk")
            .setMethodCallHandler { call, result ->
                if (call.method == "apk") {
                    val info = applicationInfo
                    result.success(
                        mapOf(
                            "caminho" to info.sourceDir,
                            "dividido" to !info.splitSourceDirs.isNullOrEmpty(),
                        )
                    )
                } else if (call.method == "telaAcesa") {
                    // Passar a biblioteca para outro celular: com a tela
                    // apagada, o Wi-Fi pode cair no meio.
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                } else if (call.method == "versao") {
                    // Para avisar quando sai versão nova do Farol.
                    result.success(packageManager.getPackageInfo(packageName, 0).versionName)
                } else {
                    result.notImplemented()
                }
            }
    }
}
