package studio.chaosmos.kit;

import android.app.Activity;
import android.content.pm.PackageInfo;
import android.os.Build;

import com.google.android.play.core.appupdate.AppUpdateInfo;
import com.google.android.play.core.appupdate.AppUpdateManager;
import com.google.android.play.core.appupdate.AppUpdateManagerFactory;
import com.google.android.play.core.appupdate.AppUpdateOptions;
import com.google.android.play.core.install.model.AppUpdateType;
import com.google.android.play.core.install.model.InstallStatus;
import com.google.android.play.core.install.model.UpdateAvailability;
import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Google Play's in-app review and in-app updates, for the kit's PlayCore (kit/shell/play_core.gd), which calls
 * these static methods through JavaClassWrapper. Each answer is a state string the game polls, so no Java
 * callback ever has to cross into Godot. Play's tasks report back on the main thread, where the review card
 * and the update flows are launched from.
 */
public final class PlayCore {
	private static volatile String review = "idle";
	/** idle, none, available, asking, downloading, downloaded, installing, installed or failed. */
	private static volatile String update = "idle";
	private static volatile String info = "{}";
	private static volatile long downloaded = 0L;
	private static volatile long total = 0L;
	private static AppUpdateManager updates;
	private static AppUpdateInfo last;

	private PlayCore() {}

	/** Play's review card: "asking", then "done" once the flow ends, whether or not Play showed it, or "failed". */
	public static void requestReview(final Activity activity) {
		if ("asking".equals(review)) {
			return;
		}
		review = "asking";
		activity.runOnUiThread(() -> {
			final ReviewManager manager = ReviewManagerFactory.create(activity);
			manager.requestReviewFlow().addOnCompleteListener(request -> {
				if (!request.isSuccessful()) {
					review = "failed";
					return;
				}
				manager.launchReviewFlow(activity, request.getResult()).addOnCompleteListener(flow -> review = "done");
			});
		});
	}

	public static String reviewState() {
		return review;
	}

	/**
	 * Asks Play whether a newer version is out, on every launch, with no wait for it to go stale: the game shows its
	 * own card. updateState() becomes "available" (updateInfo() says which version, its priority and which flows
	 * Play allows), "none", "downloading", "downloaded" or "failed". An immediate update the player left resumes.
	 */
	public static void checkUpdate(final Activity activity) {
		activity.runOnUiThread(() -> {
			manager(activity).getAppUpdateInfo().addOnSuccessListener(found -> {
				last = found;
				describe(found);
				int status = found.installStatus();
				if (status == InstallStatus.DOWNLOADED) {
					update = "downloaded";
				} else if (status == InstallStatus.DOWNLOADING || status == InstallStatus.PENDING) {
					update = "downloading";
				} else if (found.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
					update = "installing";
					manager(activity).startUpdateFlow(found, activity, AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE));
				} else if (found.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
					update = "available";
				} else {
					update = "none";
				}
			}).addOnFailureListener(error -> update = "failed");
		});
	}

	/**
	 * Starts the update the last check found: flexible (Play asks once, then it downloads while the game goes on) or
	 * immediate (Play's own full screen until it is installed). A flexible one the player declines is "available"
	 * again.
	 */
	public static void startUpdate(final Activity activity, final boolean immediate) {
		activity.runOnUiThread(() -> {
			final int type = immediate ? AppUpdateType.IMMEDIATE : AppUpdateType.FLEXIBLE;
			if (last == null || !last.isUpdateTypeAllowed(type)) {
				update = "failed";
				return;
			}
			update = immediate ? "installing" : "asking";
			manager(activity).startUpdateFlow(last, activity, AppUpdateOptions.defaultOptions(type))
				.addOnSuccessListener(result -> {
					if (result != Activity.RESULT_OK && ("asking".equals(update) || "installing".equals(update))) {
						update = "available";
					}
				})
				.addOnFailureListener(error -> update = "failed");
		});
	}

	public static String updateState() {
		return update;
	}

	/** The update as a small JSON object: code, priority, staleness (-1 when Play does not say), bytes, downloaded,
	 * flexible and immediate (whether Play allows each). */
	public static String updateInfo() {
		return info;
	}

	/** Installs the downloaded update: Play shows its own screen, then the game opens again on the new version. */
	public static void completeUpdate() {
		if (updates != null) {
			update = "installing";
			updates.completeUpdate();
		}
	}

	/** The version code running now, so the game can tell an update has been installed. */
	public static long versionCode(final Activity activity) {
		try {
			PackageInfo pkg = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0);
			return Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ? pkg.getLongVersionCode() : pkg.versionCode;
		} catch (Exception error) {
			return 0L;
		}
	}

	private static AppUpdateManager manager(final Activity activity) {
		if (updates == null) {
			updates = AppUpdateManagerFactory.create(activity);
			updates.registerListener(state -> {
				int status = state.installStatus();
				if (status == InstallStatus.DOWNLOADING || status == InstallStatus.PENDING) {
					downloaded = state.bytesDownloaded();
					total = state.totalBytesToDownload();
					update = "downloading";
				} else if (status == InstallStatus.DOWNLOADED) {
					downloaded = total;
					update = "downloaded";
				} else if (status == InstallStatus.INSTALLED) {
					update = "installed";
				} else if (status == InstallStatus.FAILED) {
					update = "failed";
				} else if (status == InstallStatus.CANCELED) {
					update = "available";
				}
				refresh();
			});
		}
		return updates;
	}

	private static void describe(final AppUpdateInfo found) {
		total = found.totalBytesToDownload();
		downloaded = found.bytesDownloaded();
		refresh();
	}

	private static void refresh() {
		final AppUpdateInfo found = last;
		final JSONObject out = new JSONObject();
		try {
			out.put("code", found != null ? found.availableVersionCode() : 0);
			out.put("priority", found != null ? found.updatePriority() : 0);
			Integer stale = found != null ? found.clientVersionStalenessDays() : null;
			out.put("staleness", stale != null ? stale : -1);
			out.put("bytes", total);
			out.put("downloaded", downloaded);
			out.put("flexible", found != null && found.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE));
			out.put("immediate", found != null && found.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE));
		} catch (JSONException error) {
			return;
		}
		info = out.toString();
	}
}
