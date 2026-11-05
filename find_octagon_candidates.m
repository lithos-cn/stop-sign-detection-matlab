function [candidates, diagnostics] = find_octagon_candidates(mask, param)
% FIND_OCTAGON_CANDIDATES Propose octagons from a binary red mask.
candidates = {};
scores = [];
diagnostics = struct('regions', 0, 'size_pass', 0, 'shape_pass', 0, ...
                     'above_old_max_area', 0);
% Use multiple opening strengths to separate thin attachments.
radius = min(8, max(3, round(0.012 * min(size(mask)))));
mask_list = {mask, imopen(mask, strel('disk', radius)), ...
             imopen(mask, strel('disk', 2*radius))};

for pass = 1:numel(mask_list)
    current = mask_list{pass};
    [boundaries, labels] = bwboundaries(current, 'noholes');
    stats = regionprops(labels, 'Area', 'Solidity', 'Extent', 'BoundingBox');
    for k = 1:numel(boundaries)
        diagnostics.regions = diagnostics.regions + 1;
        area = stats(k).Area;
        if area > param.max_area
            diagnostics.above_old_max_area = diagnostics.above_old_max_area + 1;
        end
        box = stats(k).BoundingBox;
        aspect = box(3) / max(box(4), eps);
        % Scale the upper area limit to the image size.
        if area < param.min_area || area > 0.5 * numel(mask) || ...
                aspect < 0.40 || aspect > 2.0 || ...
                min(box(3:4)) < 18
            continue;
        end
        diagnostics.size_pass = diagnostics.size_pass + 1;

        boundary = boundaries{k};
        xy = [double(boundary(:,2)), double(boundary(:,1))];
        if size(xy, 1) < 8
            continue;
        end
        try
            hull_index = convhull(xy(:,1), xy(:,2));
        catch
            continue;
        end
        hull_pts = choose_eight_hull_vertices(xy(hull_index(1:end-1), :));
        component = labels == k;
        [valid_hull, hull_score] = check_octagon(hull_pts, component, box);
        [regular_pts, regular_score] = fit_regular_octagon(component, box);
        if regular_score > hull_score
            pts = regular_pts;
            shape_score = regular_score;
        else
            pts = hull_pts;
            shape_score = hull_score;
        end
        if ~valid_hull && regular_score == -inf
            continue;
        end
        diagnostics.shape_pass = diagnostics.shape_pass + 1;

        % Merge nearby proposals across passes, retaining the higher rank.
        center = mean(pts, 1);
        duplicate = 0;
        for j = 1:numel(candidates)
            old = candidates{j};
            old_size = max(old, [], 1) - min(old, [], 1);
            if norm(center - mean(old, 1)) < 0.12 * min(old_size)
                duplicate = j;
                break;
            end
        end
        rank = shape_score * log(area + 1);
        if duplicate == 0
            candidates{end+1} = pts; %#ok<AGROW>
            scores(end+1) = rank; %#ok<AGROW>
        elseif rank > scores(duplicate)
            candidates{duplicate} = pts;
            scores(duplicate) = rank;
        end
    end
end
if ~isempty(candidates)
    [~, order] = sort(scores, 'descend');
    candidates = candidates(order);
end
end

function pts = choose_eight_hull_vertices(pts)
% Remove the least significant hull vertices until eight remain.
if size(pts, 1) < 8
    pts = [];
    return;
end
while size(pts, 1) > 8
    prev = pts([end 1:end-1], :);
    next = pts([2:end 1], :);
    edge = next - prev;
    deviation = abs(edge(:,1).*(pts(:,2)-prev(:,2)) - ...
                    edge(:,2).*(pts(:,1)-prev(:,1))) ./ ...
                max(hypot(edge(:,1), edge(:,2)), eps);
    [~, discard] = min(deviation);
    pts(discard, :) = [];
end
end

function [valid, score] = check_octagon(pts, component, box)
if isempty(pts)
    valid = false; score = -inf; return;
end
edges = pts([2:end 1], :) - pts;
lengths = hypot(edges(:,1), edges(:,2));
if min(lengths) < 0.055 * min(box(3:4)) || ...
        max(lengths) / min(lengths) > 7
    valid = false; score = -inf; return;
end
next_edges = edges([2:end 1], :);
turns = atan2(edges(:,1).*next_edges(:,2) - edges(:,2).*next_edges(:,1), ...
              sum(edges .* next_edges, 2));
turn_degrees = abs(turns) * 180/pi;
if any(turns * sign(sum(turns)) <= 0) || ...
        any(turn_degrees < 18 | turn_degrees > 80) || std(turn_degrees) > 23
    valid = false; score = -inf; return;
end
poly_mask = poly2mask(pts(:,1), pts(:,2), size(component,1), size(component,2));
overlap = nnz(poly_mask & component) / max(nnz(poly_mask | component), 1);
valid = overlap >= 0.75;
score = overlap * exp(-std(turn_degrees) / 45);
if ~valid
    score = -inf;
end
end

function [pts, score] = fit_regular_octagon(component, box)
% Fit an axis-aligned octagon and require high component overlap.
x0 = box(1); y0 = box(2); w = box(3); h = box(4);
cut = 0.29;
pts = [x0+cut*w, y0; x0+(1-cut)*w, y0; ...
       x0+w, y0+cut*h; x0+w, y0+(1-cut)*h; ...
       x0+(1-cut)*w, y0+h; x0+cut*w, y0+h; ...
       x0, y0+(1-cut)*h; x0, y0+cut*h];
poly_mask = poly2mask(pts(:,1), pts(:,2), size(component,1), size(component,2));
overlap = nnz(poly_mask & component) / max(nnz(poly_mask | component), 1);
if overlap < 0.86 || w/h < 0.65 || w/h > 1.55
    pts = [];
    score = -inf;
else
    score = overlap;
end
end
