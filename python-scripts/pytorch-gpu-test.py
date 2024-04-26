import torch

def main():
    # Check if GPUs are available
    if torch.cuda.is_available():
        device_count = torch.cuda.device_count()
        print(f"Number of available GPUs: {device_count}")

        # Utilize all available GPUs
        for i in range(device_count):
            device = torch.device(f"cuda:{i}")
            print(f"Using GPU {i}: {torch.cuda.get_device_name(i)}")
            # Run a simple computation on each GPU
            with torch.cuda.device(device):
                a = torch.randn(1000, 1000).cuda()
                b = torch.randn(1000, 1000).cuda()
                c = torch.matmul(a, b)
                # Ensure the computation is finished
                torch.cuda.synchronize()

        print("All GPUs are utilized.")
    else:
        print("No GPUs available. Make sure CUDA is properly installed.")

if __name__ == "__main__":
    main()
