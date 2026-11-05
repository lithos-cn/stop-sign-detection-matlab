function pts = extract_octagon_vertices(img, param)
% EXTRACT_OCTAGON_VERTICES Return the largest geometric candidate without NCC.
[mask, ~] = red_segmentation(img, param);
cands = find_octagon_candidates(mask, param);

if isempty(cands)
    pts = [];
    return;
end

% Select the candidate with the largest polygon area.
areas = cellfun(@(p) polyarea(p(:,1),p(:,2)), cands);
[~, idx] = max(areas);
pts = cands{idx};
end
