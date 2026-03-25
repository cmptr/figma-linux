// Inject frame fix before main app loads
const Module = require('module');
const originalRequire = Module.prototype.require;

console.log('[Frame Fix] Wrapper loaded');

Module.prototype.require = function(id) {
	const module = originalRequire.apply(this, arguments);

	if (id === 'electron' || id === 'electron/main') {
		console.log('[Frame Fix] Intercepting electron module');
		const OriginalBrowserWindow = module.BrowserWindow;
		const OriginalMenu = module.Menu;

		if (OriginalBrowserWindow && !OriginalBrowserWindow.__figma_patched) {
			module.BrowserWindow = class BrowserWindowWithFrame extends OriginalBrowserWindow {
				constructor(options) {
					// Detect tray window by its preload script path
					const preloadPath = options?.webPreferences?.preload || '';
					const isTrayWindow = preloadPath.includes('tray_binding_renderer');

					if (isTrayWindow) {
						console.log('[Frame Fix] Tray notification BrowserWindow detected');
					} else {
						console.log('[Frame Fix] BrowserWindow constructor called');
					}

					if (process.platform === 'linux') {
						options = options || {};
						const originalFrame = options.frame;
						// Force native frame
						options.frame = true;
						// Hide the menu bar by default (Alt key will toggle it)
						options.autoHideMenuBar = true;
						// Remove custom titlebar options
						delete options.titleBarStyle;
						delete options.titleBarOverlay;
						console.log(`[Frame Fix] Modified frame from ${originalFrame} to true`);
					}
					super(options);
					// Hide menu bar after window creation on Linux
					if (process.platform === 'linux') {
						this.setMenuBarVisibility(false);

						// Wayland fix: content bounds update asynchronously, so when
						// entering/leaving fullscreen or maximize, the first resize
						// fires before the geometry is final. Re-emit resize after a
						// short delay so the app recalculates child view bounds.
						const isWayland = process.argv.includes('--ozone-platform=wayland')
							|| (process.env.WAYLAND_DISPLAY && !process.argv.includes('--ozone-platform=x11'));
						if (isWayland && !isTrayWindow) {
							const forceResizeUpdate = () => {
								setTimeout(() => {
									if (!this.isDestroyed()) {
										this.emit('resize');
									}
								}, 150);
							};
							this.on('maximize', forceResizeUpdate);
							this.on('unmaximize', forceResizeUpdate);
							this.on('enter-full-screen', forceResizeUpdate);
							this.on('leave-full-screen', forceResizeUpdate);
							console.log('[Frame Fix] Wayland resize workaround enabled');
						}

						// Debug: open DevTools for tray notification window
						if (isTrayWindow && process.env.FIGMA_DEBUG === '1') {
							console.log('[Frame Fix] DEBUG: Opening DevTools for tray window');
							this.webContents.on('dom-ready', () => {
								this.webContents.openDevTools({ mode: 'detach' });
							});
						}
					}
				}
			};

			// Copy static methods and properties (but NOT prototype, that's already set by extends)
			for (const key of Object.getOwnPropertyNames(OriginalBrowserWindow)) {
				if (key !== 'prototype' && key !== 'length' && key !== 'name') {
					try {
						const descriptor = Object.getOwnPropertyDescriptor(OriginalBrowserWindow, key);
						if (descriptor) {
							Object.defineProperty(module.BrowserWindow, key, descriptor);
						}
					} catch (e) {
						// Ignore errors for non-configurable properties
					}
				}
			}

			module.BrowserWindow.__figma_patched = true;
		}

		// Intercept Menu.setApplicationMenu to hide menu bar on Linux
		if (OriginalMenu && !OriginalMenu.__figma_patched) {
			const originalSetAppMenu = OriginalMenu.setApplicationMenu.bind(OriginalMenu);
			module.Menu.setApplicationMenu = function(menu) {
				console.log('[Frame Fix] Intercepting setApplicationMenu');
				originalSetAppMenu(menu);
				if (process.platform === 'linux') {
					// Hide menu bar on all existing windows after menu is set
					for (const win of module.BrowserWindow.getAllWindows()) {
						win.setMenuBarVisibility(false);
					}
					console.log('[Frame Fix] Menu bar hidden on all windows');
				}
			};
			OriginalMenu.__figma_patched = true;
		}
	}

	return module;
};
