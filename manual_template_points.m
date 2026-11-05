% MANUAL_TEMPLATE_POINTS Annotate and save eight template vertices.
clear; clc; close all;

% Run from the project folder containing the template.
template = imread('template_stop.jpg');  % Update the filename if using a PNG template.
imshow(template);
title('请按【顺时针或逆时针】依次点击STOP标志的8个角点，点完8个后按Enter', 'FontSize', 12);

% Select vertices in clockwise or counterclockwise order.
pts = ginput(8);

% Display the selected vertices and polygon.
hold on;
plot(pts(:,1), pts(:,2), 'yo', 'MarkerSize', 10, 'MarkerFaceColor', 'y', 'LineWidth', 2);
plot([pts(:,1); pts(1,1)], [pts(:,2); pts(1,2)], 'g-', 'LineWidth', 2);
title('标注完成！这些点已保存', 'FontSize', 12);

% Save coordinates for subsequent detection runs.
save('template_points.mat', 'pts');
fprintf('模板顶点已保存到 template_points.mat\n');
disp('你标注的坐标为：');
disp(pts);
