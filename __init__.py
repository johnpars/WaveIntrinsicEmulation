import os
from coalpy import gpu

gpu.set_current_adapter(
    index=0,
)

root = os.path.dirname(os.path.abspath(__file__))
gpu.add_data_path("{}/shaders/".format(root))