module imgui.autocomplete;

import d_imgui.imgui_h;
import ImGui = d_imgui;

import std.algorithm.comparison;
import std.algorithm.searching;
import std.logger;
import std.range;
import std.uni;

private struct AutoCompleteState {
	bool isPopupOpen = false;
	int activeIdx = -1; // Index of currently 'active' item by use of up/down keys
	int clickedIdx = -1; // Index of popup item clicked with the mouse
	bool selectionChanged = false; // Flag to help focus the correct item when selecting active item
}
private struct AutoCompleteStateCallback(R) {
	R entries;
	bool wrap;
	AutoCompleteState state;
	int InputCallback(ref ImGuiInputTextCallbackData data) @safe pure {
		void SetInputFromActiveIndex(int entryIndex) @safe pure {
			string entry = entries[entryIndex];

			data.Buf[0 .. entry.length] = entry;
			data.BufTextLen = cast(int)entry.length;
			data.BufDirty = true;
		}
		switch (data.EventFlag) {
			case ImGuiInputTextFlags.CallbackCompletion:
				if (state.isPopupOpen && (state.activeIdx != -1)) {
					// Tab was pressed, grab the item's text
					SetInputFromActiveIndex(state.activeIdx);
				}

				state.isPopupOpen = false;
				state.activeIdx = -1;
				state.clickedIdx = -1;
				break;
			case ImGuiInputTextFlags.CallbackHistory:
				if (data.EventKey.among(ImGuiKey.UpArrow, ImGuiKey.DownArrow)) {
					int newIdx = getNextIndex(entries, data.Buf[0 .. data.BufTextLen], state.activeIdx, data.EventKey == ImGuiKey.UpArrow, wrap);
					state.selectionChanged = newIdx != state.activeIdx;
					state.activeIdx = newIdx;
				}
				state.isPopupOpen = state.activeIdx != -1;
				break;
			case ImGuiInputTextFlags.CallbackAlways:
				if (state.clickedIdx != -1) {
					// The user has clicked an item, grab the item text
					SetInputFromActiveIndex(state.clickedIdx);

					// Hide the popup
					state.isPopupOpen = false;
					state.activeIdx = -1;
					state.clickedIdx = -1;
				}
				break;
			case ImGuiInputTextFlags.CallbackCharFilter:
				break;
			default: break;
		}

		return 0;
	}
}

struct AutoComplete {
	bool wrap = true; // Selection wraps around when pressing up/down
	AutoCompleteState state;
	private const(char)[] DrawInput(R)(R entries, string label, out ImVec2 popupPos, out ImVec2 popupSize, out bool isFocused) {
		static int InputCallback(ImGuiInputTextCallbackData* data) @system pure {
			AutoCompleteStateCallback!R* state = cast(AutoCompleteStateCallback!R*)data.UserData;
			return state.InputCallback(*data);
		}
		static char[256] inputBuf = '\0';
		const flags = ImGuiInputTextFlags.EnterReturnsTrue |
			ImGuiInputTextFlags.CallbackAlways |
			ImGuiInputTextFlags.CallbackCharFilter |
			ImGuiInputTextFlags.CallbackCompletion |
			ImGuiInputTextFlags.CallbackHistory;

		auto callbackState = AutoCompleteStateCallback!R(entries, wrap, state);

		if (ImGui.InputText(label, inputBuf[], flags, cast(ImGuiInputTextCallback)&InputCallback, &callbackState)) {
			if (callbackState.state.isPopupOpen && (callbackState.state.activeIdx != -1)) {
				// This means that enter was pressed whilst
				// the popup was open and we had an 'active' item.
				// So we copy the entry to the input buffer here
				string entry = entries[callbackState.state.activeIdx];

				inputBuf[0 .. entry.length] = entry;
				inputBuf[entry.length] = '\0';
			} else {
				// Handle text input here
				inputBuf[0] = '\0';
			}

			// Hide popup
			callbackState.state.isPopupOpen = false;
			callbackState.state.activeIdx = -1;
		}
		state = callbackState.state;
		isFocused = ImGui.IsItemFocused();

		// Restore focus to the input box if we just clicked an item
		if(state.clickedIdx != -1) {
			ImGui.SetKeyboardFocusHere(-1);

			// NOTE: We do not reset the 'clickedIdx' here because
			// we want to let the callback handle it in order to
			// modify the buffer, therefore we simply restore keyboard input instead
			state.isPopupOpen = false;
		}

		// Get input box position, so we can place the popup under it
		popupPos = ImGui.GetItemRectMin();

		// Grab the position for the popup
		popupSize = ImVec2(ImGui.GetItemRectSize().x - 60, ImGui.GetFrameHeightWithSpacing() * 4);
		popupPos.y += ImGui.GetItemRectSize().y;
		return inputBuf[0 .. inputBuf[].countUntil('\0')];
	}

	private bool DrawPopup(R)(R entries, const ImVec2 pos, const ImVec2 size, const char[] input) {
		if (!state.isPopupOpen) {
			return false;
		}

		ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0);

		const flags =
			ImGuiWindowFlags.NoTitleBar |
			ImGuiWindowFlags.NoResize |
			ImGuiWindowFlags.NoMove |
			ImGuiWindowFlags.HorizontalScrollbar |
			ImGuiWindowFlags.NoFocusOnAppearing |
			ImGuiWindowFlags.NoSavedSettings;


		ImGui.SetNextWindowPos(pos);
		ImGui.SetNextWindowSize(size);
		ImGui.BeginChild("input_popup", ImVec2(), false, flags);
		ImGui.PushTabStop(false);

		foreach (idx, entry; entries.enumerate) {
			if (!entry.startsWith!((x,y) => std.uni.toLower(x) == std.uni.toLower(y))(input)) {
				continue;
			}
			// Track if we're drawing the active index so we
			// can scroll to it if it has changed
			bool isIndexActive = state.activeIdx == idx;

			if (isIndexActive) {
				// Draw the currently 'active' item differently
				// (used appropriate colors for your own style)
				ImGui.PushStyleColor(ImGuiCol.Border, ImVec4(1, 0, 0, 1));
			}

			ImGui.PushID(cast(int)idx);
			if (ImGui.Selectable(entry, isIndexActive)) {
				// And item was clicked, notify the input
				// callback so that it can modify the input buffer
				state.clickedIdx = cast(int)idx;
			}
			ImGui.PopID();

			if (isIndexActive) {
				if (state.selectionChanged){
					// Make sure we bring the currently 'active' item into view.
					ImGui.SetScrollHereY();
					state.selectionChanged = false;
				}

				ImGui.PopStyleColor(1);
			}
		}

		const result = ImGui.IsWindowFocused(ImGuiFocusedFlags.RootWindow);

		ImGui.PopTabStop();
		ImGui.EndChild();
		ImGui.PopStyleVar(1);
		return result;
	}
	const(char)[] Draw(R)(string label, R entries) {
		ImVec2 popupPos, popupSize;
		bool isWindowFocused;

		// Draw the main window
		const input = DrawInput(entries, label, popupPos, popupSize, isWindowFocused);

		// Draw the popup window
		const isPopupFocused = DrawPopup(entries, popupPos, popupSize, input);

		// If neither of the windows has focus, hide the popup
		if(!isWindowFocused && !isPopupFocused) {
			state.isPopupOpen = false;
		}
		return input;
	}
}

private int getNextIndex(alias pred = (x,y) => x.startsWith!((x,y) => std.uni.toLower(x) == std.uni.toLower(y))(y), R)(R haystack, const char[] needle, int current, bool up, bool wrap) {
	int newIdx = current;
	if (newIdx == -1) {
		newIdx = cast(int)haystack.length;
	}
	for (ulong iterationsLeft = haystack.length; iterationsLeft > 0; iterationsLeft--) {
		if (up) {
			if (newIdx > 0) {
				newIdx--;
			} else if (wrap && (newIdx == 0)) {
				newIdx = cast(int)haystack.length - 1;
			}
		} else {
			if (newIdx < haystack.length - 1) {
				newIdx++;
			} else if (newIdx >= haystack.length - 1) {
				if (wrap) {
					newIdx = 0;
				} else {
					newIdx= cast(int)haystack.length - 1;
				}
			}
		}
		if ((newIdx < 0) || (newIdx >= haystack.length)) {
			debug infof("%s, %s, %s, %s, %s", haystack, needle, current, up, wrap);
		}
		if (pred(haystack[newIdx], needle)) {
			break;
		}
	}
	if (!pred(haystack[newIdx], needle)) { // if no match found, try to work backwards from starting point
		newIdx = -1;
		if (up) {
			foreach (idx, entry; haystack[(current == -1) ? 0 : current .. $].enumerate) {
				if (pred(entry, needle)) {
					newIdx = cast(int)idx;
					break;
				}
			}
		} else {
			foreach_reverse (idx, entry; haystack[0 .. (current == -1) ? $ : current].enumerate) {
				if (pred(entry, needle)) {
					newIdx = cast(int)idx;
					break;
				}
			}
		}
	}
	return newIdx;
}

@safe pure unittest {
	const test = ["1", "2", "3"];
	assert(getNextIndex(test, "", 0, false, false) == 1);
	assert(getNextIndex(test, "", 2, false, false) == 2);
	assert(getNextIndex(test, "2", 2, false, false) == 1);
	assert(getNextIndex(test, "", 2, false, true) == 0);
	assert(getNextIndex(test, "", 1, true, false) == 0);
	assert(getNextIndex(test, "", 0, true, false) == 0);
	assert(getNextIndex(test, "", 0, true, true) == 2);
	assert(getNextIndex(test, "2", 0, true, false) == 1);
	assert(getNextIndex(test, "4", -1, false, true) == -1);
	assert(getNextIndex(test, "4", -1, false, false) == -1);
	assert(getNextIndex(test, "4", -1, true, true) == -1);
	assert(getNextIndex(test, "4", -1, true, false) == -1);
}
