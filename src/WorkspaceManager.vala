//
//  Copyright (C) 2014 Tom Beckmann, Rico Tzschichholz
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Meta;

namespace Gala {
    public class WorkspaceManager : Object {
        public static void init (WindowManager wm) requires (instance == null) {
            instance = new WorkspaceManager (wm);
        }

        public static unowned WorkspaceManager get_default () requires (instance != null) {
            return instance;
        }

        static WorkspaceManager? instance = null;

        public WindowManager wm { get; construct; }

        Gee.LinkedList<Workspace> workspaces_marked_removed;
        int remove_freeze_count = 0;

        WorkspaceManager (WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            workspaces_marked_removed = new Gee.LinkedList<Workspace> ();
            unowned Meta.Display display = wm.get_display ();
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();

            // There are some empty workspace at startup
            cleanup ();

            if (Prefs.get_dynamic_workspaces ())
                manager.override_workspace_layout (DisplayCorner.TOPLEFT, false, 1, -1);

            for (var i = 0; i < manager.get_n_workspaces (); i++)
                workspace_added (manager, i);

            Prefs.add_listener (prefs_listener);

            manager.workspace_switched.connect_after (workspace_switched);
            manager.workspace_added.connect (workspace_added);
            manager.workspace_removed.connect_after (workspace_removed);
            display.window_entered_monitor.connect (window_entered_monitor);
            display.window_left_monitor.connect (window_left_monitor);

            // make sure the last workspace has no windows on it
            if (Prefs.get_dynamic_workspaces ()
                && Utils.get_n_windows (manager.get_workspace_by_index (manager.get_n_workspaces () - 1)) > 0)
                append_workspace ();
        }

        ~WorkspaceManager () {
            Prefs.remove_listener (prefs_listener);

            unowned Meta.Display display = wm.get_display ();
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            manager.workspace_added.disconnect (workspace_added);
            manager.workspace_switched.disconnect (workspace_switched);
            manager.workspace_removed.disconnect (workspace_removed);
            display.window_entered_monitor.disconnect (window_entered_monitor);
            display.window_left_monitor.disconnect (window_left_monitor);
        }

        void workspace_added (Meta.WorkspaceManager manager, int index) {
            var workspace = manager.get_workspace_by_index (index);
            if (workspace == null)
                return;

            workspace.window_added.connect (window_added);
            workspace.window_removed.connect (window_removed);
        }

        void workspace_removed (Meta.WorkspaceManager manager, int index) {
            List<Workspace> existing_workspaces = null;
            for (int i = 0; i < manager.get_n_workspaces (); i++) {
                existing_workspaces.append (manager.get_workspace_by_index (i));
            }

            var it = workspaces_marked_removed.iterator ();
            while (it.next ()) {
                var workspace = it.@get ();

                if (existing_workspaces.index (workspace) < 0)
                    it.remove ();
            }
        }

        void workspace_switched (Meta.WorkspaceManager manager, int from, int to, MotionDirection direction) {
            if (!Prefs.get_dynamic_workspaces ())
                return;

            // remove empty workspaces after we switched away from them unless it's the last one
            var prev_workspace = manager.get_workspace_by_index (from);
            if (Utils.get_n_windows (prev_workspace) < 1
                && from != manager.get_n_workspaces () - 1) {

                // If we're about to remove a workspace, cancel any DnD going on in the multitasking view
                // or else things might get broke
                DragDropAction.cancel_all_by_id ("multitaskingview-window");

                remove_workspace (prev_workspace);
            }
        }

        void window_added (Workspace? workspace, Window window) {
            if (workspace == null || !Prefs.get_dynamic_workspaces ()
                || window.on_all_workspaces)
                return;

            unowned Meta.WorkspaceManager manager = workspace.get_display ().get_workspace_manager ();
            int last_workspace = manager.get_n_workspaces () - 1;

            if ((window.window_type == WindowType.NORMAL
                || window.window_type == WindowType.DIALOG
                || window.window_type == WindowType.MODAL_DIALOG)
                && workspace.index () == last_workspace)
                append_workspace ();
        }

        void window_removed (Workspace? workspace, Window window) {
            if (workspace == null || !Prefs.get_dynamic_workspaces () || window.on_all_workspaces)
                return;

            unowned Meta.WorkspaceManager manager = workspace.get_display ().get_workspace_manager ();
            var index = workspace.index ();
            bool is_active_workspace = workspace == manager.get_active_workspace ();
            int last_workspace = manager.get_n_workspaces () - 1;

            if (window.window_type != WindowType.NORMAL
                && window.window_type != WindowType.DIALOG
                && window.window_type != WindowType.MODAL_DIALOG)
                return;

            // has already been removed
            if (index < 0)
                return;

            // remove it right away if it was the active workspace and it's not the very last
            // or we are in modal-mode
            if ((!is_active_workspace || wm.is_modal ())
                && remove_freeze_count < 1
                && Utils.get_n_windows (workspace) < 1
                && index != last_workspace) {
                remove_workspace (workspace);
            }
        }

        void window_entered_monitor (Meta.Display display, int monitor, Window window) {
            if (InternalUtils.workspaces_only_on_primary ()
                && monitor == display.get_primary_monitor ())
                window_added (window.get_workspace (), window);
        }

        void window_left_monitor (Meta.Display display, int monitor, Window window) {
            if (InternalUtils.workspaces_only_on_primary ()
                && monitor == display.get_primary_monitor ())
                window_removed (window.get_workspace (), window);
        }

        void prefs_listener (Meta.Preference pref) {
            unowned Meta.WorkspaceManager manager = wm.get_display ().get_workspace_manager ();

            if (pref == Preference.DYNAMIC_WORKSPACES && Prefs.get_dynamic_workspaces ()) {
                // if the last workspace has a window, we need to append a new workspace
                if (Utils.get_n_windows (manager.get_workspace_by_index (manager.get_n_workspaces () - 1)) > 0)
                    append_workspace ();
            }
        }

        void append_workspace () {
            unowned Meta.Display display = wm.get_display ();
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();

            manager.append_new_workspace (false, display.get_current_time ());
        }

        /**
         * Make sure we switch to a different workspace and remove the given one
         *
         * @param workspace The workspace to remove
         */
        void remove_workspace (Workspace workspace) {
            unowned Meta.Display display = workspace.get_display ();
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var time = display.get_current_time ();
            unowned Meta.Workspace active_workspace = manager.get_active_workspace ();

            if (workspace == active_workspace) {
                Workspace? next = null;

                next = workspace.get_neighbor (MotionDirection.LEFT);
                // if it's the first one we may have another one to the right
                if (next == workspace || next == null)
                    next = workspace.get_neighbor (MotionDirection.RIGHT);

                if (next != null)
                    next.activate (time);
            }

            // workspace has already been removed
            if (workspace in workspaces_marked_removed) {
                return;
            }

            workspace.window_added.disconnect (window_added);
            workspace.window_removed.disconnect (window_removed);

            workspaces_marked_removed.add (workspace);

            manager.remove_workspace (workspace, time);
        }

        /**
         * Temporarily disables removing workspaces when they are empty
         */
        public void freeze_remove () {
            remove_freeze_count++;
        }

        /**
         * Undo the effect of freeze_remove()
         */
        public void thaw_remove () {
            remove_freeze_count--;

            assert (remove_freeze_count >= 0);
        }

        /**
         * If workspaces are dynamic, checks if there are empty workspaces that should
         * be removed. Particularly useful in conjunction with freeze/thaw_remove to
         * cleanup after an operation that required stable workspace/window indices
         */
        public void cleanup () {
            if (!Prefs.get_dynamic_workspaces ())
                return;

            unowned Meta.Display display = wm.get_display ();
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            List<Meta.Workspace> workspaces = null;
            for (int i = 0; i < manager.get_n_workspaces (); i++) {
                workspaces.append (manager.get_workspace_by_index (i));
            }

            foreach (var workspace in workspaces) {
                var last_index = manager.get_n_workspaces () - 1;
                if (Utils.get_n_windows (workspace) < 1
                    && workspace.index () != last_index) {
                    remove_workspace (workspace);
                }
            }
        }
    }
}
