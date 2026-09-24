function container = makeAlertBox(parent, tag)
    arguments
        parent
        tag (1,1) string =  "message"
    end

    % Alert box for figure-based clients (documents, side panels, etc.) in toolstrip
    % apps.

    % Copyright 2026 The MathWorks, Inc.

    container = uigridlayout(parent, 'Tag', tag+"Grid");
    container.RowHeight = {'fit'};
    container.ColumnWidth = {'fit', '1x'};
    matlab.graphics.internal.themes.specifyThemePropertyMappings(...
        container, 'BackgroundColor', '--mw-backgroundColor-announcementBanner');

    img = uiimage(container, 'Tag', tag+"Icon");
    img.Layout.Row = 1;
    img.Layout.Column = 1;
    matlab.ui.control.internal.specifyIconID(img, 'info', 24);

    label = uilabel(container, 'Tag', tag+"Label");
    label.Layout.Row = 1;
    label.Layout.Column = 2;
    label.WordWrap = 'on';
end
