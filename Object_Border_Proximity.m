
close all; clear variables; clc

%% Setting and creating directories

currdir = pwd;
addpath(pwd);
filedir = uigetdir();
cd(filedir);
filedir_file = dir('*.tif');

% contains information on the cell borders
borders = [filedir, '/borders/'];
cd(borders)

% binary_tifs folder contains the binary image files of the objects
files_tifs = [filedir, '/binary_tifs'];
cd(files_tifs)
object_files = dir('*.tif');

% creating main result directory
if exist([filedir, '/analysis'],'dir') == 0
    mkdir(filedir,'/analysis');
end
analysis_folder = [filedir, '/analysis'];

%% counter for objects analysed
no_analysed_images = 0;
no_analysed_cells = 0;
no_analysed_objects = 0;

%% Obtain border imformation from 'handCorrection.tif' file generated by TissueAnalyzer

for kk = 1:numel(filedir_file)
    cd(borders)
    bd_dir = [borders, '/', num2str(kk)];
    cd(bd_dir)
    I=imread('handCorrection.tif');
    I=imbinarize(rgb2gray(I),0);
    I(:,1) = 0;
    I(:,end) = 0;
    I(1,:) = 0;
    I(end,:) = 0;
    [im_x, im_y] = size(I);
    [B,L,N,A] = bwboundaries(I,'holes');
    im_cell_data = regionprops(L, 'Centroid');

    % keep track of each image analysed
    no_analysed_images = no_analysed_images + 1
    
    % create results directory for each image
    if exist ([filedir, ['/analysis/', num2str(kk),'/by_object'], 'dir']) == 0
        mkdir (filedir, ['/analysis/', num2str(kk), '/by_object']);
    end
    results_by_object = [filedir, ['/analysis/', num2str(kk), '/by_object']];

    if exist ([filedir, ['/analysis/', num2str(kk), '/mask'], 'dir']) == 0
        mkdir (filedir, ['/analysis/', num2str(kk), '/mask']);
    end
    results_mask = [filedir, ['/analysis/', num2str(kk), '/mask']];

    if exist ([filedir, ['/analysis/', num2str(kk), '/rel_distances'], 'dir']) == 0
        mkdir (filedir, ['/analysis/', num2str(kk), '/rel_distances']);
    end
    results_sheets = [filedir, ['/analysis/', num2str(kk), '/rel_distances']];

    % determine centroid position for each cell in the image
    for ii=1:length(im_cell_data)
        x_centroid_cell(ii) = im_cell_data(ii).Centroid(1);
        y_centroid_cell(ii) = im_cell_data(ii).Centroid(2);
    end

    % excluding first element which is the parent object
    x_centroid_cell = x_centroid_cell(2:end);
    y_centroid_cell = y_centroid_cell(2:end);

    x_centroid_cell = x_centroid_cell(:);
    y_centroid_cell = y_centroid_cell(:);

    Image1= figure; 
    imshow(I); hold on;
    % Loop through object boundaries  
    % showing the cells identified with complete borders
    for k = 1:N
        % Boundary k is the parent of a hole if the k-th column
        % of the adjacency matrix A contains a non-zero element
        if (nnz(A(:,k)) > 0)
            boundary = B{k};
            plot(boundary(:,2),...
                boundary(:,1),'w','LineWidth',1);
            % Loop through the children of boundary k
            for l = find(A(:,k))'
                boundary = B{l};
                plot(boundary(:,2),...
                    boundary(:,1),'g','LineWidth',2);
            end
        end
    end; hold on; plot(x_centroid_cell, y_centroid_cell, 'r*')

    cd(analysis_folder)
    Output_Graph = [num2str(kk),'_borders'];
    hold off
    print(Image1, '-dtiff', '-r300', Output_Graph);

    % removes first cell which is the 'whole' image
    B_fixed = B;
    B_fixed(1) = []; % Note: boundary coordinates are organised in (y, x) format

    reply = questdlg(strcat('Do you want to determine centroids of objects automatically?'), 'Settings', 'Yes', 'No', 'Yes');
    
    for ww = 1:length(B_fixed)
        close all
        I_mask = imdilate(poly2mask(B_fixed{ww}(:,2),B_fixed{ww}(:,1),im_x,im_y), strel('diamond', 1));
        % read in binary image containing objects
        cd(files_tifs)
            Q = [num2str(kk),'.tif'];
            I_object = imread(Q); 
            I_object = logical(I_object);

            ROI = I_object;
            ROI(I_mask== 0) = 0;
            ROI2 = logical(ROI); %
            % Image2 = figure('visible','off');
            % imshow(ROI);
            
            % keep track of cells analysed
            no_analysed_cells = no_analysed_cells + 1

            if strcmp(reply, 'Yes')
                %% collect centroid positions calculated by regionprops function
                im_object_data = regionprops (ROI2, 'Centroid', 'PixelList');
                for jj=1:length(im_object_data)
                    x_centroid_object(jj) = im_object_data(jj).Centroid(1);
                    y_centroid_object(jj) = im_object_data(jj).Centroid(2);
                end
            elseif strcmp(reply, 'No')
                 % to determine centroid positions manually; press enter key when finished
                try, 
                    imshow(ROI2), 
                    hold on, 
                    % use the getpts() function; useful to see marked objects; backspace to remove previous point
                    [x_centroid_object, y_centroid_object] = getpts();
                    % alternatively use a color-customised version of ginput, my_ginput located in the same directory 
                    %[x_centroid_object, y_centroid_object] = my_ginput();
                catch end        
            end 
    
            % loop through individual objects within each cell
            for jj=1:length(im_object_data)
                x_centroid_object = x_centroid_object(1:length(im_object_data));
                y_centroid_object = y_centroid_object(1:length(im_object_data));

                x_centroid_object = x_centroid_object(:);
                y_centroid_object = y_centroid_object(:);

                C = imfuse(I_mask, ~ROI2); %imshow(C);
                
                % keep track of objects analysed in the session
                no_analysed_objects = no_analysed_objects + 1

                % showing centroid positions of objects within mask
                %imshow(ROI2); hold on, plot(x_centroid_object, y_centroid_object, 'r*')
                Image3 = figure('visible','off');
                imshow(C); 
                hold on, 
                plot(x_centroid_object, y_centroid_object, 'r*')
                hold off

                %% Obtain the coefficients of a straight line connecting object and cell centroids
                x = [x_centroid_cell(ww), x_centroid_object(jj)];
                y = [y_centroid_cell(ww), y_centroid_object(jj)];
                %figure, imshow(I_mask); ; hold on; plot(x,y);
                % coefficients straight line between object1 and cell centroids, y = ax + b....
                coefficients = polyfit(x, y, 1);
                a = coefficients (1); b = coefficients (2);

                % extend length of straight line through cell borders
                %x1 = linspace(0, im_x-1, im_x);
                x1 = -(im_x*2):1:im_x*2;  % create a linear vector twice the x dimension of
                y1 = polyval(coefficients, x1); 

                % Image4 = figure('visible','off');
                % imshow(C)
                % hold on
                % plot(x_centroid_cell(ww), y_centroid_cell(ww), '*r')
                % hold on
                % plot(x, y, 'O-r')
                % hold on
                % plot(x1, y1, 'b')
                % hold off

                % Border pixel coordinates for cell 1 is contained in array, B_fixed{1}
                % but stored in [y, x] format... B_coord = flip(B_fixed{1}, 2) not needed anymore
                % change matrix from [y, x] to [x, y]
                B_x = B_fixed{ww}(:,2);
                B_y = B_fixed{ww}(:,1);

                %% find intersection of line with cell border, requires Mapping Toolbox

                % Image5 = figure('visible','off');
                % mapshow(B_x, B_y,'DisplayType','polygon','LineStyle','none');
                % set(gca,'Ydir','reverse') 

                [x_int, y_int] = polyxpoly(x1, y1, B_x, B_y, 'unique'); % contains the line_border intercept

                Image6 = figure('visible','on');
                set(gca,'Ydir','reverse')
                mapshow(x_int,y_int,'DisplayType','point','Marker','o');
                hold on
                mapshow(B_x, B_y,'DisplayType','polygon','LineStyle','none');
                hold on
                plot(x_int,y_int, 'O-r')
                hold on
                plot(x_centroid_cell(ww), y_centroid_cell(ww), '*r')
                hold on
                plot(x_centroid_object(jj), y_centroid_object(jj), '*b')
                hold off

                % distances from object to both border-straight line intercepts
                dist1 = pdist([x_centroid_object(jj), y_centroid_object(jj); x_int(1), y_int(1)], 'euclidean');
                dist2 = pdist([x_centroid_object(jj), y_centroid_object(jj); x_int(2), y_int(2)], 'euclidean');

                % select border closest to the object and store in new variable 'bl_int'
                if (dist1 < dist2)
                    bl_int = [x_int(1), y_int(1)];
                elseif (dist2 < dist1)
                    bl_int = [x_int(2), y_int(2)];
                end

                % bl_int is the border-line intercept coordinate
                bl_int_x = bl_int(1);
                bl_int_y = bl_int(2);

                % distance between cell centroid and object
                dist3 = pdist([x_centroid_cell(ww), y_centroid_cell(ww); x_centroid_object(jj), y_centroid_object(jj)], 'euclidean');

                % distance between cell centroid and border
                dist4 = pdist([x_centroid_cell(ww), y_centroid_cell(ww); bl_int_x, bl_int_y], 'euclidean');
                % alternatively use this; dist4 = norm([bl_int_x, bl_int_y] - [x_centroid_cell(1), y_centroid_cell(1)])

                % proportion of distance (rel_dist) between border and cell centroid where object is located
                % A value of '0' means an object is located in the cell centre while
                % A value of '1' means an object is right on the cell border

                rel_dist = (dist3/dist4); rel_dist(rel_dist > 1) = 1;
                rel_distances(jj) = rel_dist;
                
                % keep track of number of images, cells and objects analysed in the session
                total_no = cat(3, no_analysed_images, no_analysed_cells, no_analysed_objects);

                % cd(results_mask)
                % Output_Graph = [num2str(ww),'_masks.tif'];
                % hold off
                % print(Image2, '-dtiff', '-r300', Output_Graph)

                cd(results_mask)
                Output_Graph = ['Image' num2str(kk), '_cell' num2str(ww), '_mask_objects'];
                hold off
                print(Image3, '-dtiff', '-r300', Output_Graph)

                % cd(results_mask)
                % Output_Graph = [num2str(jj),'_centroid_object_line.tif'];
                % hold off
                % print(Image4, '-dtiff', '-r300', Output_Graph)

                % cd(results_mask)
                % Output_Graph = [num2str(ww),'_border_outline.tif'];
                % hold off
                % print(Image5, '-dtiff', '-r300', Output_Graph)

                cd(results_by_object)
                Output_Graph = ['Image' num2str(kk), '_cell' num2str(ww), '_object' num2str(jj), '_figure.tif'];
                hold off
                print(Image6, '-dtiff', '-r300', Output_Graph)

            end

            % save distances to csv file
            cd(results_sheets)
            csvwrite(['Image' num2str(kk), '_cell' num2str(ww), '_rel_distances.csv'], rel_distances(:))

    end

end

% save total number of images, cells and objects analysed
cd(analysis_folder)
csvwrite('total.csv', total_no)

close all; clear variables; clc
