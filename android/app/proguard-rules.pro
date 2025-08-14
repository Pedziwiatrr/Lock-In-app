-keep public class com.google.android.gms.ads.** {
   public *;
}

-keep public class com.google.ads.** {
   public *;
}

-keepattributes *Annotation*
-keepclassmembers class ** {
    @android.webkit.JavascriptInterface <methods>;
}