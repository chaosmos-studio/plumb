class_name Gallery
extends RefCounted

## The phone's own albums, for what a player chooses to keep: a picture into Pictures and a film into
## Movies, each in a folder named for the game, through the MediaStore, which needs no permission from
## Android 10 on. Older phones would need a storage permission, so there it answers false and the caller
## offers the share sheet instead. And a native toast, which floats over the game without being part of
## the frames it draws.

## Keeps `bytes` as `file_name` of type `mime` ("image/png", "video/mp4"). False when it cannot.
static func keep(bytes: PackedByteArray, file_name: String, mime: String) -> bool:
	if not Engine.has_singleton("AndroidRuntime") or bytes.is_empty():
		return false
	var build: Object = JavaClassWrapper.wrap("android.os.Build$VERSION")
	if build == null or int(build.get("SDK_INT")) < 29:
		return false
	var film: bool = mime.begins_with("video/")
	var activity: Object = Engine.get_singleton("AndroidRuntime").call("getActivity")
	var values: Object = JavaClassWrapper.wrap("android.content.ContentValues").call("ContentValues")
	values.call("put", "_display_name", file_name)
	values.call("put", "mime_type", mime)
	values.call("put", "relative_path", ("Movies/" if film else "Pictures/") + Brand.NAME)
	# The wrapper only reads static fields that hold numbers or text, so the collection's Uri comes from
	# getContentUri rather than EXTERNAL_CONTENT_URI.
	var media: Object = JavaClassWrapper.wrap("android.provider.MediaStore$Video$Media" if film
		else "android.provider.MediaStore$Images$Media")
	var collection: Object = media.call("getContentUri", "external")
	var resolver: Object = activity.call("getContentResolver")
	var uri: Object = resolver.call("insert", collection, values)
	if uri == null or failed("insert into the MediaStore"):
		return false
	var stream: Object = resolver.call("openOutputStream", uri)
	if stream == null or failed("open the MediaStore entry"):
		return false
	stream.call("write", bytes)
	stream.call("close")
	return not failed("write the MediaStore entry")

## Whether the last call into Java threw, said in the log with `doing`, which is where a failure on a
## phone shows up.
static func failed(doing: String) -> bool:
	var thrown: Object = JavaClassWrapper.get_exception()
	if thrown == null:
		return false
	print("%s: could not %s: %s" % [Brand.NAME, doing, String(thrown.call("toString"))])
	return true

## A short native note at the foot of the screen, outside anything the game draws.
static func say(text: String) -> void:
	if not Engine.has_singleton("AndroidRuntime"):
		return
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Object = runtime.call("getActivity")
	var toasts: Object = JavaClassWrapper.wrap("android.widget.Toast")
	activity.call("runOnUiThread", runtime.call("createRunnableFromGodotCallable", func() -> void:
		toasts.call("makeText", activity, text, 0).call("show")))
