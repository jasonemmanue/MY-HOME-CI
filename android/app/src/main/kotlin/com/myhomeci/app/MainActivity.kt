// Le package doit suivre le `namespace` declare dans build.gradle.kts
// (com.myhomeci.app) : le manifeste designe l'activite par « .MainActivity »,
// nom relatif que la fusion resout contre le namespace. Un package different
// ici compile sans erreur mais fait echouer l'instanciation au lancement
// (ClassNotFoundException), l'application se fermant sur un ecran blanc.
package com.myhomeci.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
