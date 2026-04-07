FROM ubuntu:22.04

# 1. 设置非交互模式，避免安装时的 tzdata 等弹窗阻塞
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/opt/conda/bin:$PATH

WORKDIR /app

# 2. 优化系统依赖安装，加入 libgl1-mesa-glx (Streamlit/OpenCV 常用)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    git \
    && rm -rf /var/lib/apt/lists/*

# 3. 安装 Miniconda 并立即清理
RUN wget --quiet https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh && \
    conda clean -afy

# 4. 彻底重置 Conda 配置，避免 .condarc 残留错误
RUN conda config --remove-key channels || true && \
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/ && \
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/ && \
    conda config --set show_channel_urls yes

# 5. 【关键优化】先复制 environment.yml 以利用镜像层缓存
COPY environment.yml .

# 6. 修正环境创建：强制忽略 environment.yml 中的 channels 声明
# 使用 --override-channels 配合我们前面定义的清华源，防止它去连官方源
RUN conda env create -n cellvoyager -f environment.yml --override-channels --channel https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/ && \
    conda clean -afy

# 7. 修正 Streamlit 安装方式
# 确保在 cellvoyager 环境中安装，并处理可能的依赖冲突
RUN conda run -n cellvoyager pip install --no-cache-dir streamlit -i https://pypi.tuna.tsinghua.edu.cn/simple

# 8. 复制项目代码
COPY . .

EXPOSE 8501

# 9. 修正启动命令：增加 --no-capture-output 确保日志实时输出
# 建议加上 SHELL 指令，让后续命令默认在 conda 环境下跑（可选）
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "cellvoyager"]
CMD ["streamlit", "run", "run_cellvoyager.py", "--server.port=8501", "--server.address=0.0.0.0"]