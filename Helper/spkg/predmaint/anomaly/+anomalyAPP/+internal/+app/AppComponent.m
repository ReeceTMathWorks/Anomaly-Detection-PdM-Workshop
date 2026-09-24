classdef AppComponent < handle
    % Base class for app components needing state data management.

    % Copyright 2025 The MathWorks, Inc.

    properties (Access = protected)
        StateStore anomalyAPP.internal.utils.StateStore
    end

    properties (Access = private)
        Key (1,1) string

        Dirty (1,1) logical = false
        Visible (1,1) logical = true

        StateStoreListener event.listener
    end

    methods
        function obj = AppComponent(key, stateStore)
            obj.Key = key;

            obj.StateStore = stateStore;
            obj.StateStore.registerState(obj.Key);

            weakObj = matlab.lang.WeakReference(obj);
            obj.StateStoreListener = listener(stateStore, 'StateChanged', @(~,ed) update(weakObj.Handle,ed));
            obj.StateStoreListener.Recursive = true; % Can be called with different state keys.
        end

        function visible = isVisible(obj)
            visible = obj.Visible;
        end

        function setVisible(obj, visible)
            obj.Visible = visible;
        end

        function delete(obj)
            %fprintf("Component for '%s' is being deleted.\n", obj.Key);
            obj.StateStore.removeState(obj.Key);
        end
    end

    % State management
    methods (Abstract, Access = protected)
        reset(obj)
        update_(obj, ed)
        render_(obj, force)
    end

    methods (Access = private)
        function update(obj, ed)
            % Update component's OWN state upon changes in OTHER components' states.
            if (obj.Key ~= ed.Name)
                try
                    update_(obj, ed);
                catch E
                    fprintf("Updating the component state '%s' was not successful.\n", obj.Key);
                    rethrow(E);
                end
            end

            % Render the component view only if it is visible and if its OWN state may have changed.
            if obj.Visible && (obj.Key == ed.Name)
                render(obj);
            end
        end
    end

    methods (Access = {?anomalyAPP.internal.app.TimeSeriesAnomalyDetector})
        function render(obj, options)
            arguments
                obj
                options.Force (1,1) logical = false % Force the component to render, regardless of the dirty state
            end
            % Render the component view if the component state has changed.
            if obj.Dirty || options.Force
                try
                    render_(obj, options.Force); % Some components may have their own definitions of dirty, so let them know if they should force render regardless of dirtiness
                    obj.Dirty = false;
                catch E
                    fprintf("Rendering the component view for '%s' was not successful.\n", obj.Key);
                    obj.Dirty = false; % Set to not dirty even if render fails in order to avoid infinite loops.
                    rethrow(E);
                end
            end
        end
    end

    methods (Access = protected)
        function setState(obj, state)
            % Sets own state data.
            dirty = obj.StateStore.setState(obj.Key, state);
            obj.Dirty = obj.Dirty || dirty;

            % Notify observers AFTER the Dirty state has been established.
            if obj.Dirty
                ed = anomalyAPP.internal.utils.EventData(obj.Key);
                obj.StateStore.notify('StateChanged', ed);
            end
        end

        function state = getState(obj, key)
            % Gets own or other state data.
            arguments
                obj
                key (1,1) string = obj.Key
            end
            state = obj.StateStore.getState(key);
        end

        function flag = hasState(obj, key)
            % Check if a state has been registered.
            flag = obj.StateStore.hasState(key);
        end
    end

    % QE Methods
    methods (Hidden, Access={?matlab.unittest.TestCase})
        function state = qeGetState(obj)
            state = getState(obj);
        end

        function qeSetState(obj, state)
            setState(obj, state);
        end

        function qeReset(obj)
            reset(obj);
        end

        function qeRender(obj, options)
            arguments
                obj
                options.Force (1,1) logical = false
            end
            render(obj, Force=options.Force);
        end
    end
end
