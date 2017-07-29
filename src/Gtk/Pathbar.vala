/*
 * Pathbar.vala
 *
 * Copyright 2017 Tony George <teejeetech@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */


using Gtk;
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class Pathbar : Gtk.Box {

	// reference properties ----------

	private MainWindow window{
		get { return App.main_window; }
	}
	
	FileViewPane _pane;
	private FileViewPane? pane {
		get{
			if (_pane != null){ return _pane; }
			else { return window.active_pane; }
		}
	}

	private FileViewList? view{
		get{ return (pane == null) ? null : pane.view; }
	}

	private LayoutPanel? panel {
		get { return (pane == null) ? null : pane.panel; }
	}

	// -------------------------------
	
	private Gtk.Box scrolled_box;
	private Gtk.Box link_box;
	private Gtk.EventBox ebox_edit_buffer;
	private Gtk.ScrolledWindow scrolled;

	private Gtk.Box box_left;

	private Gtk.EventBox ebox_back;
	private Gtk.Image img_back;

	private Gtk.EventBox ebox_next;
	private Gtk.Image img_next;

	private Gtk.EventBox ebox_up;
	private Gtk.Image img_up;

	private Gtk.EventBox ebox_bookmark;
	private Gtk.Image img_bookmark;

	private Gtk.EventBox ebox_disk;
	private Gtk.Image img_disk;

	private Gtk.EventBox ebox_swap;
	private Gtk.Image img_swap;

	private Gtk.EventBox ebox_open_other;
	private Gtk.Image img_open_other;

	private Gtk.EventBox ebox_close;
	private Gtk.Image img_close;

	private Gtk.Image img_edit;
	private int ICON_SIZE = 16;

	private Gtk.Entry txt_path;
	private int BOX_SPACING = 3;

	private Gtk.Menu menu_disk;
	private Gtk.Menu menu_bookmark;

	public bool path_edit_mode = false;

	private bool is_global{
		get{
			return (_pane == null);
		}
	}

	// contructors

	public Pathbar(FileViewPane? parent_pane){
		//base(Gtk.Orientation.VERTICAL, 6); // issue with vala
		Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6); // work-around
		margin = 6;
		//spacing = 0;
		homogeneous = false;

		/* Note: Pathbar spacing is 0, Add left, top, bottom margins to each item */

		log_debug("Pathbar()");

		_pane = parent_pane;

		//var box = new Gtk.Box(Orientation.HORIZONTAL, 6);
		//box.homogeneous = false;
		//box.margin_left = 6;
		//box.margin_right = 3;
		//add(box);
		
		add_item_back(this);

		add_item_next(this);

		add_item_up(this);

		add_item_bookmarks(this);

		add_item_disk(this);

		add_item_link_box();

		add_item_open_other();

		add_item_swap();

		//add_item_close();

		this.set_no_show_all(true);

        log_debug("Pathbar():exit");
	}

	// bookmarks

	private Gtk.Popover popup_bm;
	private Sidebar sidebar_bm;

	private void add_item_bookmarks(Gtk.Box box){

		log_debug("Pathbar: add_item_bookmarks()");

		var ebox = gtk_add_event_box(box);
		ebox_bookmark = ebox;

		var img = new Gtk.Image();
		ebox.add(img);
		img_bookmark = img;

		var tt = _("Bookmarks");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		popup_bm = new Gtk.Popover(ebox);
		sidebar_bm = new Sidebar(popup_bm, "bm", pane);
		popup_bm.add(sidebar_bm);
		
		ebox.button_press_event.connect((event)=>{
			//menu_bookmark_popup(null);
			sidebar_bm.show();
			sidebar_bm.refresh();
			gtk_show(popup_bm);
			return false;
		});
	}

	// disk menu

	private Gtk.Popover popup_dev;
	private Sidebar sidebar_dev;

	private void add_item_disk(Gtk.Box box){

		log_debug("Pathbar: add_item_disk()");

		var ebox = gtk_add_event_box(box);
		//ebox.margin = 1;
		//ebox.margin_left = 6;
		//ebox.margin_right = 6;
		ebox_disk = ebox;

		var img = IconManager.lookup_image("drive-harddisk",16);
		ebox.add(img);
		img_disk = img;

		var tt = _("Open Device");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		// set hand cursor
		if (ebox.get_realized()){
			ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
		}
		else{
			ebox.realize.connect(()=>{
				ebox.get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.HAND1));
			});
		}

		popup_dev = new Gtk.Popover(ebox);
		sidebar_dev = new Sidebar(popup_dev, "device", pane);
		popup_dev.add(sidebar_dev);

		ebox.button_press_event.connect((event)=>{
			sidebar_dev.show();
			sidebar_dev.refresh();
			gtk_show(popup_dev);
			//menu_disk_popup(null);
			return false;
		});
	}

	// path links

	private void add_item_link_box(){

		// scrolled
		scrolled = new Gtk.ScrolledWindow(null, null);
		scrolled.hexpand = true;
		scrolled.hscrollbar_policy = PolicyType.AUTOMATIC; // clips child without showing scrollbar
		scrolled.vscrollbar_policy = PolicyType.NEVER;
		//scrolled.set_shadow_type(ShadowType.ETCHED_IN);
		add(scrolled);

		scrolled.hadjustment.changed.connect(()=>{
			var adj = scrolled.hadjustment;
			var maxval = adj.upper - adj.page_size;
			if (adj.value != maxval){
				adj.set_value(maxval);
				log_debug("%.0f, %.0f, %.0f".printf(adj.value, adj.upper, adj.page_size));
			}
		});

		// scrolled_box
		var box = new Gtk.Box(Orientation.HORIZONTAL, 0);
		box.homogeneous = false;
		scrolled.add(box);
		scrolled_box = box;

		add_item_entry();

		// link_box
		box = new Gtk.Box(Orientation.HORIZONTAL, 0);
		box.homogeneous = false;
		scrolled_box.add(box);
		link_box = box;

		add_item_path_edit_buffer();

		//add_item_bookmarks();
	}

	private void add_item_entry(){

		var txt = new Gtk.Entry();
		txt.xalign = 0.0f;
		txt.hexpand = true;
		txt.margin = 0;
		txt_path = txt;
		scrolled_box.add(txt);

		// will be connected on edit
		//txt.activate.connect(txt_path_activate);

		txt.focus_out_event.connect((event) => {
			txt.activate();
			return false;
		});

		// connect signal for shift+F10
        txt.popup_menu.connect(() => {
			return true; // suppress right-click menu
		});

        // connect signal for right-click
		txt.button_press_event.connect((w, event) => {
			if (event.button == 3) {
				return true; // suppress right-click menu
			}
			return false;
		});
		
		txt.set_no_show_all(true);
	}

	private void add_item_path_edit_buffer(){

		var ebox = gtk_add_event_box(scrolled_box);
		var label = new Gtk.Label("");
		label.hexpand = true;
		ebox.add(label);
		ebox_edit_buffer = ebox;

		string tt = _("Click to edit path");
		ebox.set_tooltip_text(tt);
		label.set_tooltip_text(tt);

		ebox.button_press_event.connect((event) => {
			edit_location();
			return true;
		});
	}

	// refresh

	public void refresh(){

		log_debug("Pathbar: refresh()");

		refresh_visibility();

		if (!this.visible){ return; }

		if (pane == null){ return; }

		refresh_path();

		refresh_icon_visibility();

		refresh_icon_state();

		//changed(); // signal
	}

	public void refresh_for_active_pane(){

		refresh_path();

		refresh_icon_state();
	}

	private void refresh_visibility(){

		log_debug("Pathbar: refresh_visibility()");
		
		if (!App.headerbar_enabled && ((this.is_global && App.pathbar_unified) || (!this.is_global && !App.pathbar_unified))){
			this.set_no_show_all(false);
			this.show_all();
		}
		else{
			this.set_no_show_all(true);
			this.hide();
		}

		log_debug("Pathbar: refresh_visibility(): exit");
	}

	public void refresh_path(){
		update_crumbs();
	}

	public void refresh_icon_visibility(){

		// bookmarks ---------------

		if (App.pathbar_show_bookmarks){
			gtk_show(ebox_bookmark);
		}
		else{
			gtk_hide(ebox_bookmark);
		}

		// disks ---------------

		if (App.pathbar_show_disks){
			gtk_show(ebox_disk);
			link_box.margin_left = 0;
		}
		else{
			gtk_hide(ebox_disk);
			link_box.margin_left = 6;
		}

		// back ---------------

		if (App.pathbar_show_back){
			gtk_show(ebox_back);
		}
		else{
			gtk_hide(ebox_back);
		}

		// next ---------------

		if (App.pathbar_show_next){
			gtk_show(ebox_next);
		}
		else{
			gtk_hide(ebox_next);
		}

		// up ---------------

		if (App.pathbar_show_up){
			gtk_show(ebox_up);
		}
		else{
			gtk_hide(ebox_up);
		}

		// swap ---------------

		if (panel.visible && panel.opposite_panel.visible && App.pathbar_show_swap){
			gtk_show(ebox_swap);
		}
		else{
			gtk_hide(ebox_swap);
		}

		// other ---------------

		if (App.pathbar_show_other){
			gtk_show(ebox_open_other);
		}
		else{
			gtk_hide(ebox_open_other);
		}

		if ((panel.number == 1)||(panel.number == 3)){
			img_open_other.pixbuf = IconManager.lookup_image("go-next",ICON_SIZE).pixbuf;
		}
		else if ((panel.number == 2)||(panel.number == 4)){
			img_open_other.pixbuf = IconManager.lookup_image("go-previous",ICON_SIZE).pixbuf;
		}

		// margins ----------------------------

		if (App.pathbar_show_other){
			ebox_open_other.margin_left = 3;
		}

		if (App.pathbar_show_swap){
			ebox_swap.margin_right = 3;
		}

		if (!App.pathbar_show_swap){
			ebox_open_other.margin_right = 3;
		}
		else{
			ebox_open_other.margin_right = 0;
		}

		if (!App.pathbar_show_other){
			ebox_swap.margin_left = 3;
		}
		else{
			ebox_swap.margin_left = 0;
		}

		// close ---------------

		/*if (App.pathbar_show_close){
			gtk_show(ebox_close);
		}
		else{
			gtk_hide(ebox_close);
		}*/
	}

	public void refresh_icon_state(){
		if (view.current_item != null){
			var path = view.current_item.file_path;
			if (GtkBookmark.is_bookmarked(path)){
				img_bookmark.pixbuf = IconManager.lookup("user-bookmarks", 16, false);
			}
			else{
				img_bookmark.pixbuf = IconManager.lookup("bookmark-missing", 16, false);
			}
		}
	}


	private void update_crumbs(){

		log_debug("Pathbar: update_crumbs()");

		link_box.forall ((x) => link_box.remove (x));

		if (view.current_location == null){
			// add dummy widget - maintains hbox height when empty
			var buffer = new Gtk.LinkButton("");
			buffer.sensitive = false;
			buffer.hexpand = true;
			link_box.add(buffer);
			return;
		}

		//Gtk.Label lbl;

		log_debug("update_crumb_labels()", true);
		//log_debug("file_path: %s".printf(view.current_item.file_path));
		//log_debug("file_path_prefix: %s".printf(view.current_item.file_path_prefix));
		//log_debug("display_path: %s".printf(view.current_item.display_path));
		log_debug("current_path_saved: %s".printf(view.current_location));

		switch(App.pathbar_style){
		case PathbarStyle.COMPACT:
		case PathbarStyle.FLAT_BUTTONS:
			link_box.spacing = 0;
			break;
			
		case PathbarStyle.ARROWS:
		case PathbarStyle.BUTTONS:
			link_box.spacing = 3;
			break;
		}

		string[] parts = null;

		string basepath = GvfsMounts.get_gvfs_basepath(view.current_location); // scheme:///

		string link_path = basepath[0:basepath.length-1]; // scheme://

		log_debug("basepath: %s".printf(basepath));

		add_crumb(link_box, basepath.replace("file://",""), link_path);

		parts = view.current_location.replace(link_path, "").split("/");
		
		/*string link_path = "";
		//string prefix = view.current_item.file_path_prefix;
		bool is_trash = false;
		
		if ((view.current_item != null) && (view.current_item.is_trash || view.current_item.is_trashed_item)){

			is_trash = true;

			link_path = "trash://";
			
			add_crumb(link_box, "trash://", link_path);
		}
		else { //if (view.current_item.is_local){

			link_path = "/";

			add_crumb(link_box, "/", link_path);
		}*/

		if (App.pathbar_style == PathbarStyle.ARROWS){
			add_crumb_separator(link_box);
		}

		int index = -1;

		foreach(var part in parts){
			index++;
			if (part.length == 0){ continue; }

			// crumb ----------------
			
			link_path = link_path + "/" + part; // don't use path_combine()

			add_crumb(link_box, part, link_path);

			// separator ------------
			
			bool add_separator = false;
			if ((App.pathbar_style == PathbarStyle.COMPACT) || (App.pathbar_style == PathbarStyle.ARROWS)){
				if (index < parts.length - 1){
					add_separator = true;
				}
			}

			if (add_separator){
				add_crumb_separator(link_box);
			}
		}

		link_box.show_all();

		log_debug("Pathbar: update_crumbs():exit");
	}

	private void add_crumb(Gtk.Box box, string text, string link_path){

		log_debug("add_crumb: %s, %s".printf(text, link_path));
		
		if ((App.pathbar_style == PathbarStyle.BUTTONS) || (App.pathbar_style == PathbarStyle.FLAT_BUTTONS)){
			add_crumb_button(box, text, link_path);
		}
		else{
			add_crumb_label(box, text, link_path);
		}
	}
	
	private void add_crumb_label(Gtk.Box box, string text, string link_path){
		
		var label = new Gtk.Label(text);
		label.set_use_markup(true);
		label.margin = 0;
		label.margin_bottom = 1;
		label.set_data<string>("link", link_path);
		label.set_tooltip_text(link_path);

		//gtk_apply_css( { label }, "padding-top: 0px; padding-bottom: 0px; margin-top: 0px; margin-bottom: 0px;");
		
		var ebox = gtk_add_event_box(box);
		ebox.add(label);
		
		ebox.button_press_event.connect((event) => {
			view.set_view_path(label.get_data<string>("link"));
			return true;
		});

		ebox.enter_notify_event.connect((event) => {
			//log_debug("label.enter_notify_event()");
			if (label.label == ".."){
				label.label = "<u>%s</u>".printf("..");
			}
			else{
				label.label = "<u>%s</u>".printf(text);
			}
			return false;
		});

		ebox.leave_notify_event.connect((event) => {
			//log_debug("label.leave_notify_event()");
			if (label.label == "<u>..</u>"){
				label.label = "%s".printf("..");
			}
			else{
				label.label = "%s".printf(text);
			}
			return false;
		});
	}

	private void add_crumb_button(Gtk.Box box, string text, string link_path){

		var button = new Gtk.Button();
		button.set_tooltip_text(link_path);
		button.set_data<string>("link", link_path);
		box.add(button);

		if (App.pathbar_style == PathbarStyle.FLAT_BUTTONS){
			button.relief = Gtk.ReliefStyle.NONE;
		}
		else{
			button.relief = Gtk.ReliefStyle.NORMAL;
		}
		
		var label = new Gtk.Label(text);
		label.margin = 0;
		label.margin_left = label.margin_right = 0;
		button.add(label);

		if ((App.pathbar_style == PathbarStyle.FLAT_BUTTONS) && (text != "/") && !text.contains("://")){
			label.label = "➤ " + text;
		}
		
		button.clicked.connect(() => {
			if (view == null) { return; };
			view.set_view_path(button.get_data<string>("link"));
			return;
		});
	}

	private void add_crumb_separator(Gtk.Box box){

		string separator = "➤";

		switch(App.pathbar_style){
		case PathbarStyle.COMPACT:
			separator = "/";
			break;
			
		case PathbarStyle.ARROWS:
			separator = "➤";
			break;
			
		case PathbarStyle.BUTTONS:
		case PathbarStyle.FLAT_BUTTONS:
			// pad with space
			separator = "%s ".printf(separator);
			break;
		}
		
		var label = new Gtk.Label(separator);
		box.add(label);
	}
	
	// navigation buttons

	private void add_item_back(Gtk.Box box){

		log_debug("Pathbar: add_item_back()");

		var ebox = gtk_add_event_box(box);
		ebox_back = ebox;

		var img = IconManager.lookup_image("go-previous", 16);
		ebox.add(img);
		img_back = img;

		var tt =  _("Back");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		ebox.button_press_event.connect((event)=>{

			if (event.button != 1) { return false; }

			if (view == null) { return true; };

			var path = view.history_go_back();
			if (path.length > 0){
				view.set_view_path(path, false); // update_history = false
			}

			return true;
		});
	}

	private void add_item_next(Gtk.Box box){

		log_debug("Pathbar: add_item_next()");

		var ebox = gtk_add_event_box(box);
		ebox_next = ebox;

		var img = IconManager.lookup_image("go-next", 16);
		ebox.add(img);
		img_next = img;

		var tt =  _("Next");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		ebox.button_press_event.connect((event)=>{

			if (event.button != 1) { return false; }
			
			if (view == null) { return true; };

			var path = view.history_go_forward();
			if (path.length > 0){
				view.set_view_path(path, false); // update_history = false
			}

			return true;
		});
	}

	private void add_item_up(Gtk.Box box){

		log_debug("Pathbar: add_item_up()");

		var ebox = gtk_add_event_box(box);
		ebox_up = ebox;

		var img = IconManager.lookup_image("go-up", 16);
		ebox.add(img);
		img_up = img;

		var tt =  _("Go Up");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		ebox.button_press_event.connect((event)=>{

			if (event.button != 1) { return false; }
			
			if (view == null) { return true; };

			var path = view.get_location_up();
			if (path.length > 0){
				view.set_view_path(path, false); // update_history = false
			}

			return true;
		});
	}

	// panel buttons

	private void add_item_open_other(){

		log_debug("Pathbar: add_item_open_other()");

		var ebox = gtk_add_event_box(this);
		ebox.margin_left = 3;
		ebox.margin_right = 0;
		ebox_open_other = ebox;

		var img = IconManager.lookup_image("go-next", 16);
		ebox.add(img);
		img_open_other = img;

		var tt = _("Open this directory path in opposite pane");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		ebox.button_press_event.connect((event)=>{
			if (event.button != 1) { return false; }
			view.open_location_in_opposite_pane();
			return true;
		});
	}

	private void add_item_swap(){

		log_debug("Pathbar: add_item_swap()");

		var ebox = gtk_add_event_box(this);
		ebox.margin_left = 0;
		ebox.margin_right = 3;
		ebox_swap = ebox;

		var img = IconManager.lookup_image("switch", 16);
		ebox.add(img);
		img_swap = img;

		var tt = _("Swap directory path with opposite pane");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		ebox.button_press_event.connect((event)=>{
			if (event.button != 1) { return false; }
			view.swap_location_with_opposite_pane();
			return true;
		});
	}

	private void add_item_close(){

		log_debug("Pathbar: add_item_close()");

		var ebox = gtk_add_event_box(this);
		ebox.margin_right = 3;
		ebox_close = ebox;

		var img = IconManager.lookup_image("window-close", 16);
		ebox.add(img);
		img_close = img;

		var tt = _("Close this pane");
		img.set_tooltip_text(tt);
		ebox.set_tooltip_text(tt);

		ebox.button_press_event.connect((event)=>{

			if (event.button != 1) { return false; }

			if (pane.tab.show_file_operation_warning_on_close() == Gtk.ResponseType.NO){
				return false;
			}

			gtk_hide(panel);
			panel.opposite_pane.pathbar.refresh_icon_visibility();
			//window.layout_box.set_panel_layout(PanelLayout.CUSTOM);
			window.active_pane = panel.opposite_pane;

			return true;
		});
	}

	// actions

	public void edit_location(){

		window.update_accelerators_for_edit();

		path_edit_mode = true;
		txt_path.text = view.current_location;
		txt_path.select_region(0, txt_path.text.length);

		gtk_hide(link_box);
		gtk_hide(ebox_edit_buffer);
		gtk_show(txt_path);

		txt_path.grab_focus();

		txt_path.activate.connect(txt_path_activate);
	}

	private void txt_path_activate(){

		path_edit_mode = false;

		txt_path.activate.disconnect(txt_path_activate);

		bool handled = false;
		
		if (GvfsMounts.is_gvfs_uri(txt_path.text)){
			var file = File.new_for_uri(txt_path.text);
			if (file.query_exists()){
				view.set_view_path(file.get_path());
				handled = true;
			}
			else{
				var win = new ConnectServerWindow(window, txt_path.text);
				handled = true;
			}
		}

		if (!handled && (view.current_item == null) || (view.current_item.display_path != txt_path.text)){
			view.set_view_path(txt_path.text);
			// set_view_path() will show message if not existing
		}

		gtk_hide(txt_path);
		gtk_show(link_box);
		gtk_show(ebox_edit_buffer);
		update_crumbs();

		window.update_accelerators_for_active_pane();
	}
}
