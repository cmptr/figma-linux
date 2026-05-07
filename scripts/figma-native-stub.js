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
// DEBUG: temporary diagnostics for font enumeration. Use console.error so
// the lines reach launcher.log (debug-level Figma logs are filtered out).
console.error('[figma-native-stub] module loaded, __dirname=', __dirname);

let fontEnum;
try {
	fontEnum = require('./font-enum');
	console.error('[figma-native-stub] font-enum loaded OK, exports=', Object.keys(fontEnum));
} catch (e) {
	// Defensive fallback: if font-enum fails to load, fall back to empty results
	// rather than crashing the renderer. Logs go to the Electron console.
	console.error('[figma-native-stub] failed to load font-enum:', e && e.message, e && e.stack);
	fontEnum = {
		getFonts: () => JSON.stringify({}),
		getFontsModifiedAt: () => 0,
		getModifiedFonts: () => JSON.stringify({}),
	};
}

function summarize(jsonStr) {
	try {
		const obj = JSON.parse(jsonStr);
		const paths = Object.keys(obj);
		let faces = 0;
		const families = new Set();
		for (const p of paths) for (const f of obj[p] || []) { faces++; families.add(f.family); }
		return `paths=${paths.length} faces=${faces} families=${families.size}`;
	} catch (e) {
		return `unparseable(${typeof jsonStr})`;
	}
}

module.exports.desktop_rust = {
	getFonts: () => {
		console.error('[figma-native-stub] desktop_rust.getFonts() called');
		try {
			const result = fontEnum.getFonts();
			console.error('[figma-native-stub] getFonts result:', summarize(result));
			return result;
		} catch (e) {
			console.error('[figma-native-stub] getFonts threw:', e && e.message, e && e.stack);
			return JSON.stringify({});
		}
	},
	getFontsModifiedAt: () => {
		console.error('[figma-native-stub] desktop_rust.getFontsModifiedAt() called');
		try {
			const r = fontEnum.getFontsModifiedAt();
			console.error('[figma-native-stub] getFontsModifiedAt:', r);
			return r;
		} catch (e) {
			console.error('[figma-native-stub] getFontsModifiedAt threw:', e && e.message);
			return 0;
		}
	},
	getModifiedFonts: () => {
		console.error('[figma-native-stub] desktop_rust.getModifiedFonts() called');
		try {
			const result = fontEnum.getModifiedFonts();
			console.error('[figma-native-stub] getModifiedFonts result:', summarize(result));
			return result;
		} catch (e) {
			console.error('[figma-native-stub] getModifiedFonts threw:', e && e.message);
			return JSON.stringify({});
		}
	},
};
