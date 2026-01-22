import numpy as np
try:
    data = np.load('keypoints_data.npy', allow_pickle=True)
    print(f'Shape: {data.shape}')
    print(f'Data type: {data.dtype}')
    if len(data) > 0:
        print(f'Sample: {data[0]}')
except Exception as e:
    print(f"Error loading file: {e}")
