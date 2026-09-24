function setAlertBoxMessage(fig, type, msg, tag)
    arguments
        fig
        type (1,1) string {mustBeMember(type, ["info","warning"])} = "info"
        msg (1,1) string = ""
        tag (1,1) string =  "message"
    end

    % Alert box messages and icons for figure-based clients (documents, side panels,
    % etc.) in toolstrip apps.

    % Copyright 2026 The MathWorks, Inc.

    img = findobj(fig, 'Type', 'uiimage', 'Tag', tag+"Icon");
    grid = findobj(fig, 'Type', 'uigridlayout', 'Tag', tag+"Grid");

    % Update the icon and background color of the banner based on the type of
    % message.
    switch lower(type)
        case "info"
            matlab.ui.control.internal.specifyIconID(img, 'info', 24);
            matlab.graphics.internal.themes.specifyThemePropertyMappings(...
                grid, 'BackgroundColor', '--mw-backgroundColor-announcementBanner');
        case "warning"
            matlab.ui.control.internal.specifyIconID(img, 'warning', 24);
            matlab.graphics.internal.themes.specifyThemePropertyMappings(...
                grid, 'BackgroundColor', '--mw-backgroundColor-notificationBanner');
    end

    % Update the text of the message.
    label = findobj(fig, 'Type', 'uilabel', 'Tag', tag+"Label");
    label.Text = msg;

    % If there is no message, hide the banner.
    row = grid.Layout.Row;
    grid.Visible = matlab.lang.OnOffSwitchState(msg ~= "");
    if msg ~= ""
        grid.Parent.RowHeight{row} = 'fit';
    else
        grid.Parent.RowHeight{row} = 0;
    end
end
