import os
from coalpy import gpu

print("TesT")

gpu.set_current_adapter(
    index=1,
)

root = os.path.dirname(os.path.abspath(__file__))
gpu.add_data_path("{}/shaders/".format(root))