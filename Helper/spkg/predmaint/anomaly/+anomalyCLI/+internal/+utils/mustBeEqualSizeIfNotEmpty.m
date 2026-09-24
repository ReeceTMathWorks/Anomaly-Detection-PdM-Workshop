function mustBeEqualSizeIfNotEmpty(a,b)
% MUSTBEEQUALSIZEOREMPTY Validate that two inputs are either equal in size or one is empty.
%
%   MUSTBEEQUALSIZEOREMPTY(A, B) checks if inputs A and B are either of
%   equal size or if at least one of them is empty. If neither condition
%   is met, the function throws an error indicating the mismatch.
%
%   Inputs:
%       A - The first input array. Can be of any type that supports the
%           'size' and 'isempty' functions (e.g., numeric arrays, cell arrays, etc.).
%       B - The second input array. Must be of the same type as A and
%           support the 'size' and 'isempty' functions.
%
%   Example:
%       % Example with equal sizes
%       x = [1, 2, 3];
%       y = [4, 5, 6];
%       mustBeEqualSizeOrEmpty(x, y); % No error
%
%       % Example with one empty
%       x = [];
%       y = [4, 5, 6];
%       mustBeEqualSizeOrEmpty(x, y); % No error
%
%       % Example with unequal sizes and neither empty
%       x = [1, 2, 3];
%       y = [4; 5; 6];
%       mustBeEqualSizeOrEmpty(x, y); % Throws an error
%

%   Copyright 2025 The MathWorks, Inc.

if ~isempty(a) && ~isequal(length(a),length(b))
    error(message('predmaint_anomaly:anomaly:errNotEqualSizeNorEmpty'))
end

end
