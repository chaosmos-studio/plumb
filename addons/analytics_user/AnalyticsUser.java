package studio.chaosmos.kit;

import android.app.Activity;

import com.google.firebase.analytics.FirebaseAnalytics;

/**
 * Firebase Analytics user properties for the kit's Analytics (kit/monetize/analytics.gd), which calls this through
 * JavaClassWrapper, and only while counting. The vendored Firebase plugin exposes only initialize, log_event,
 * set_consent and collection on or off, so it cannot set them itself.
 */
public final class AnalyticsUser {
	private AnalyticsUser() {}

	/** Sets user property `name` (at most 24 characters) to `value` (at most 36). */
	public static void set(final Activity activity, final String name, final String value) {
		FirebaseAnalytics.getInstance(activity).setUserProperty(name, value);
	}
}
