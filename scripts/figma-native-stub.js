// Stub implementation of Figma native modules (bindings.node + desktop_rust.node) for Linux
// These modules are Windows-specific native addons that need stubbing on Linux

let nativeTheme = null;
try {
	nativeTheme = require('electron').nativeTheme;
} catch (e) {
	// May fail in utility process where electron main APIs aren't available
}

// ---- bindings.node stubs ----
// All methods that xe.* references in main.js

module.exports = {
	// System detection
	isSystemDarkMode: () => nativeTheme ? nativeTheme.shouldUseDarkColors : false,
	isP3ColorSpaceCapable: () => false,
	getCurrentKeyboardLayout: () => 'com.apple.keylayout.US',
	getExecutableVersion: () => '0.0.0',
	getBundleVersion: () => '0',
	getAppPathForProtocol: () => '',
	getActiveNSScreens: () => [],
	getOSNotificationsEnabled: () => true,

	// Window management
	isWindowUnderPoint: () => false,
	getWindowUnderCursor: () => null,
	getWindowScreenshot: () => null,
	forceFocusWindow: () => {},

	// Panel management (macOS-specific NSPanel)
	makePanel: () => null,
	showPanel: () => {},
	hidePanel: () => {},
	positionPanel: () => {},
	destroyPanel: () => {},
	getPanelVisibility: () => false,

	// GPU stats (Windows-specific)
	getWindowsGPUStats: () => ({}),
	getGpuProcessMemorySharedUsageMB: () => 0,
	getGpuProcessMemoryDedicatedUsageMB: () => 0,
	getGpu3dUsageAsync: (callback) => { if (callback) callback(0); },

	// Cursor/Eyedropper (Windows/macOS native)
	startEyedropperSession: () => {},
	stopEyedropperSession: () => {},
	sampleEyedropperAtPoint: () => null,
	setEyedropperCursor: () => {},
	setDefaultCursor: () => {},
	requestEyedropperPermission: () => true,
	updateEyedropperColorSpace: () => {},
	startCursorTracker: () => {},

	// Haptic feedback (macOS-specific)
	triggerHaptic: () => {},

	// File type registration (Windows-specific)
	registerFileTypes: () => {},
	unregisterFileTypes: () => {},

	// Menu shortcuts
	setMenuShortcuts: () => {},

	// Spellcheck / Dictionary
	SetDictionary: () => {},
	GetAvailableDictionaries: () => [],

	// macOS-specific
	launchApp: () => {},
	removeBundleDirectory: () => {},
	removeAgentRegistryLoginItem: () => {},
};

// ---- desktop_rust.node replacement ----
// Used by main.js directly (kl variable) and by bindings_worker.js utility process.
// Provides font enumeration on Windows/macOS via native Rust code; on Linux we
// reimplement the same JSON contract in pure JavaScript by parsing TTF/OTF/TTC
// headers directly. See ./font-enum/ for the implementation and tests.
let fontEnum;
try {
	fontEnum = require('./font-enum');
} catch (e) {
	// Defensive fallback: if font-enum fails to load, fall back to empty results
	// rather than crashing the renderer. Logs go to the Electron console.
	console.error('[figma-native-stub] failed to load font-enum:', e && e.message);
	fontEnum = {
		getFonts: () => JSON.stringify({}),
		getFontsModifiedAt: () => 0,
		getModifiedFonts: () => JSON.stringify({}),
	};
}

module.exports.desktop_rust = {
	getFonts: () => fontEnum.getFonts(),
	getFontsModifiedAt: () => fontEnum.getFontsModifiedAt(),
	getModifiedFonts: () => fontEnum.getModifiedFonts(),
};
