function combined = combineStruct(structList)
%   Copyright 2025 The MathWorks, Inc.

combined = struct();

for structIdx = 1:length(structList)
    base = structList{structIdx};
    field = fieldnames(base);
    for i = 1:length(field)
        combined.(field{i}) = base.(field{i});
    end
end
end
