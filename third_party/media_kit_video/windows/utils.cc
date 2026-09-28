// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "utils.h"

typedef LONG NTSTATUS, *PNTSTATUS;
#define STATUS_SUCCESS (0x00000000)

typedef NTSTATUS(WINAPI* RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);

void Utils::EnterNativeFullscreen(HWND window) {
  if (fullscreen_ || window == nullptr) {
    return;
  }

  WINDOWPLACEMENT placement{};
  placement.length = sizeof(WINDOWPLACEMENT);
  if (!::GetWindowPlacement(window, &placement)) {
    return;
  }
  MONITORINFO monitor{};
  monitor.cbSize = sizeof(MONITORINFO);
  if (!::GetMonitorInfo(::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                        &monitor)) {
    return;
  }

  const auto style = ::GetWindowLongPtr(window, GWL_STYLE);
  style_before_fullscreen_ = style;
  placement_before_fullscreen_ = placement;
  rect_before_fullscreen_ = placement.rcNormalPosition;

  // Drop the caption and sizing border, then cover the monitor. The flag is
  // set only after the move, so a window without WS_OVERLAPPEDWINDOW is not
  // left marked fullscreen while it is still the old size.
  ::SetWindowLongPtr(window, GWL_STYLE,
                     style & ~(static_cast<LONG_PTR>(WS_CAPTION) |
                               static_cast<LONG_PTR>(WS_THICKFRAME)));
  const BOOL moved = ::SetWindowPos(
      window, HWND_TOP, monitor.rcMonitor.left, monitor.rcMonitor.top,
      monitor.rcMonitor.right - monitor.rcMonitor.left,
      monitor.rcMonitor.bottom - monitor.rcMonitor.top,
      SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  if (!moved) {
    ::SetWindowLongPtr(window, GWL_STYLE, style);
    return;
  }
  fullscreen_ = true;
}

void Utils::SetAppFullscreen(bool enabled) { app_fullscreen_ = enabled; }

void Utils::ExitNativeFullscreen(HWND window) {
  if (app_fullscreen_ || !fullscreen_ || window == nullptr) {
    return;
  }
  ::SetWindowLongPtr(window, GWL_STYLE, style_before_fullscreen_);
  placement_before_fullscreen_.length = sizeof(WINDOWPLACEMENT);
  ::SetWindowPlacement(window, &placement_before_fullscreen_);
  fullscreen_ = false;
}

RTL_OSVERSIONINFOW Utils::GetWindowsVersion() {
  HMODULE handle = ::LoadLibraryW(L"ntdll.dll");
  RTL_OSVERSIONINFOW rtl_os_version_info = {0};
  rtl_os_version_info.dwBuildNumber = 0;
  rtl_os_version_info.dwOSVersionInfoSize = sizeof(rtl_os_version_info);
  if (handle) {
    RtlGetVersionPtr rtl_get_version_ptr = reinterpret_cast<RtlGetVersionPtr>(
        ::GetProcAddress(handle, "RtlGetVersion"));
    if (rtl_get_version_ptr != nullptr) {
      rtl_get_version_ptr(&rtl_os_version_info);
    }
    ::FreeLibrary(handle);
  }
  return rtl_os_version_info;
}

bool Utils::IsWindows10RTMOrGreater() {
  return GetWindowsVersion().dwBuildNumber >= 10240;
}

bool Utils::fullscreen_ = false;

bool Utils::app_fullscreen_ = false;

RECT Utils::rect_before_fullscreen_ = RECT{};

LONG_PTR Utils::style_before_fullscreen_ = 0;

WINDOWPLACEMENT Utils::placement_before_fullscreen_ = WINDOWPLACEMENT{};
