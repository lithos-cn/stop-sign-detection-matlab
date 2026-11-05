% MANUAL_TEMPLATE_POINTS Annotate and save eight template vertices.
clear; clc; close all;

% Run from the project folder containing the template.
template = imread('template_stop.jpg');  % Update the filename if using a PNG template.
imshow(template);
title('Click the eight STOP-sign corners in clockwise or counterclockwise order', 'FontSize', 12);

% Select vertices in clockwise or counterclockwise order.
pts = ginput(8);

% Display the selected vertices and polygon.
hold on;
plot(pts(:,1), pts(:,2), 'yo', 'MarkerSize', 10, 'MarkerFaceColor', 'y', 'LineWidth', 2);
plot([pts(:,1); pts(1,1)], [pts(:,2); pts(1,2)], 'g-', 'LineWidth', 2);
title('Annotation complete', 'FontSize', 12);

% Save coordinates for subsequent detection runs.
save('template_points.mat', 'pts');
fprintf('Template vertices saved to template_points.mat\n');
disp('Annotated coordinates:');
disp(pts);
