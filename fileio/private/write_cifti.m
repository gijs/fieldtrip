function write_cifti(filename, source, varargin)

% WRITE_CIFTI writes a source structure according to FT_DATATYPE_SOURCE to a cifti file.
%
% Use as
%   write_cifti(filename, source, ...)
% where optional input arguments should come in key-value pairs and may include
%   parameter    = string, fieldname that contains the data
%   parcellation = string, fieldname that descripbes the (optional) parcellation
%
% See also READ_CIFTI

% Copyright (C) 2013, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

parcellation = ft_getopt(varargin, 'parcellation');
parameter    = ft_getopt(varargin, 'parameter');
precision    = ft_getopt(varargin, 'precision', 'double');

if ~isempty(parcellation)
  assert(ft_datatype(source, 'parcellation') || ft_datatype(source, 'segmentation'), 'the input structure does not define a parcellation');
end

if isfield(source, 'transform')
  % it represents source estimates on regular 3-D grid
  modeltype = 'voxel';
elseif isfield(source, 'tri')
  % it represents source estimates on a triangulated cortical sheet
  modeltype = 'surface';
else
  % it represents source estimates with an unknown topological arrangement
  modeltype = 'unknown';
end

if isfield(source, 'inside') && islogical(source.inside)
  % convert into an indexed representation
  source.inside = find(source.inside(:));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get the data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dat = source.(cfg.parameter);
if isfield(source, [cfg.parameter 'dimord'])
  dimord = source.([cfg.parameter 'dimord']);
else
  dimord = source.dimord;
end

dimtok = tokenize(dimord, '_');
if ~strcmp(dimtok{1}, 'pos')
  error('the first dimension should correspond to positions in the brain')
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% construct the NIFTI-2 header
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if false
  hdr.magic           = fread(fid, [1 8 ], 'int8=>int8'     ); % 4       `n', '+', `2', `\0','\r','\n','\032','\n' or (0x6E,0x2B,0x32,0x00,0x0D,0x0A,0x1A,0x0A)
  hdr.datatype        = fread(fid, [1 1 ], 'int16=>int16'   ); % 12      See file formats
  hdr.dim             = fread(fid, [1 8 ], 'int64=>double'  ); % 16      See file formats
  hdr.vox_offset      = fread(fid, [1 1 ], 'int64=>int64'   ); % 168     Offset of data, minimum=544
  hdr.intent_code     = fread(fid, [1 1 ], 'int32=>int32'   ); % 504     See file formats
  hdr.intent_name     = fread(fid, [1 16], 'int8=>char'     ); % 508     See file formats
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% construct the XML object describing the geometry
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tree = xmltree;
tree = set(tree, 1, 'name', 'CIFTI');
tree = attributes(tree, 'add', find(tree, 'CIFTI'), 'Version', '1.0');
tree = attributes(tree, 'add', find(tree, 'CIFTI'), 'NumberOfMatrices', '1');
tree = add(tree, find(tree, 'CIFTI'), 'element', 'Matrix');
tree = add(tree, find(tree, 'CIFTI/Matrix'), 'element', 'Volume');

tree = add(tree, find(tree, 'CIFTI/Matrix/Volume'), 'element', 'TransformationMatrixVoxelIndicesIJKtoXYZ');
tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/Volume/TransformationMatrixVoxelIndicesIJKtoXYZ'), 'DataSpace', 'NIFTI_XFORM_UNKNOWN');
tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/Volume/TransformationMatrixVoxelIndicesIJKtoXYZ'), 'TransformedSpace', 'NIFTI_XFORM_UNKNOWN');
tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/Volume/TransformationMatrixVoxelIndicesIJKtoXYZ'), 'UnitsXYZ', 'NIFTI_UNITS_MM');
tree = add(tree, find(tree, 'CIFTI/Matrix/Volume/TransformationMatrixVoxelIndicesIJKtoXYZ'), 'chardata', sprintf('%f ', source.transform));

tree = add(tree, find(tree, 'CIFTI/Matrix'), 'element', 'MatrixIndicesMap');
tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap'), 'IndicesMapToDataType', 'CIFTI_INDEX_TYPE_BRAIN_MODELS');
tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap'), 'AppliesToMatrixDimension', '0');

switch(modeltype)
  case 'voxel'
    if ~isempty(parcellation)
      % write one brainmodel per parcel
      pindex = source.([parcellation]);
      plabel = source.([parcellation 'label']);
      for i=1:numel(plabel)
        error('fixme')
      end
      
    elseif isfield(source, 'inside')
      % write one brainmodel, only include the voxels inside the brain
      tree = add(tree, find(tree, 'CIFTI/Matrix/MatrixIndicesMap'), 'element', 'BrainModel');
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'IndexOffset', sprintf('%d ', 0));
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'IndexCount', sprintf('%d ', length(source.inside)));
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'ModelType', 'CIFTI_MODEL_TYPE_VOXELS');
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'BrainStructure', 'CIFTI_STRUCTURE_CORTEX');
      tree = add(tree, find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'element', 'VoxelIndicesIJK');
      tree = add(tree, find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel/VoxelIndicesIJK'), 'chardata', sprintf('%d ', source.inside));
      
    else
      % write one brainmodel for all voxels
      tree = add(tree, find(tree, 'CIFTI/Matrix/MatrixIndicesMap'), 'element', 'BrainModel');
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'IndexOffset', sprintf('%d ', 0));
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'IndexCount', sprintf('%d ', prod(source.dim)));
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'ModelType', 'CIFTI_MODEL_TYPE_VOXELS');
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'BrainStructure', 'CIFTI_STRUCTURE_CORTEX');
      tree = add(tree, find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'element', 'VoxelIndicesIJK');
      tree = add(tree, find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel/VoxelIndicesIJK'), 'chardata', sprintf('%d ', 0:(prod(source.dim-1))));
      
    end % if parcellation, inside or all voxels
    
  case 'surface'
    if ~isempty(parcellation)
      % write one brainmodel per parcel
      pindex = source.([parcellation]);
      plabel = source.([parcellation 'label']);
      for i=1:numel(plabel)
        error('fixme')
      end
      
    elseif isfield(source, 'inside')
      % write one brainmodel, only include the voxels inside the brain
      
    else
      % write one brainmodel for all voxels
      tree = add(tree, find(tree, 'CIFTI/Matrix/MatrixIndicesMap'), 'element', 'BrainModel');
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'IndexOffset', sprintf('%d ', 0));
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'IndexCount', sprintf('%d ', size(source.pos, 1)));
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'ModelType', 'CIFTI_MODEL_TYPE_SURFACE');
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'BrainStructure', 'CIFTI_STRUCTURE_CORTEX');
      tree = attributes(tree, 'add', find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'SurfaceNumberOfNodes', sprintf('%d ', size(source.pos, 1)));
      tree = add(tree, find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel'), 'element', 'NodeIndices');
      tree = add(tree, find(tree, 'CIFTI/Matrix/MatrixIndicesMap/BrainModel/NodeIndices'), 'chardata', sprintf('%d ', 0:(size(source.pos, 1)-1)));
      
    end % if parcellation, inside or all voxels
    
  otherwise
    error('unrecognized description of the geometrical model')
end % case modeltype


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% write everything to file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 540 bytes with nifti-2 header
% 4 bytes that indicate the presence of a header extension [1 0 0 0]
% 4 bytes with the size of the header extension in big endian?
% 4 bytes with the header extension code NIFTI_ECODE_CIFTI [0 0 0 32]
% variable number of bytes with the xml section, at the end there might be some empty "junk"
% 8 bytes, presumaby with the size and type?
% variable number of bytes with the voxel data

% write the header 
write_nifti2_hdr(filename);

% open the file to append all other stuff
fid = fopen(filename, 'wb');

xmlfile = [tempname '.xml'];  % this will contain the cifti XML structure
save(tree, xmlfile);          % write the XMLTREE object to disk

xmlfid = fopen(filename, 'rb');
xmldat = fread(xmlfid, [1, inf], 'char');
fclose(xmlfid);
xmlsize = length(xmlfid);

fwrite(fid, [1 0 0 0], 'uint8');
fwrite(fid, xmlsize, 'uint32');
fwrite(fid, xmldat, 'char');
fwrite(fid, [0 0 0 0 0 0 0 0], 'uint8');
fwrite(fid, dat, precision);

