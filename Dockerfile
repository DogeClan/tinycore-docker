# Use the Debian Bookworm Slim base image
FROM debian:bookworm-slim as builder

# Set environment variables
ENV NO_VNC_HOME=/novnc
ENV WEBSOCKIFY_HOME=/websockify
ENV VNC_PORT=5901
ENV VM_MEMORY=512M
ENV VM_CPUS=1
ENV ISO_URL=http://tinycorelinux.net/15.x/x86/release/Core-current.iso
ENV ISO_FILE=Core-current.iso

# Install necessary packages for building
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        qemu-system-x86 \
        git \
        wget \
        python3 \
        python3-pip \
        x11-utils \
        xvfb && \
    pip3 install websockify && \
    rm -rf /var/lib/apt/lists/*

# Clone NoVNC and websockify from Git
RUN git clone --depth 1 https://github.com/novnc/noVNC.git ${NO_VNC_HOME} && \
    git clone --depth 1 https://github.com/novnc/websockify.git ${WEBSOCKIFY_HOME}

# Download Core ISO file
RUN wget -O ${ISO_FILE} ${ISO_URL}

# Final image
FROM debian:bookworm-slim

# Copy essential files from the builder stage
COPY --from=builder /novnc ${NO_VNC_HOME}
COPY --from=builder /websockify ${WEBSOCKIFY_HOME}
COPY --from=builder /usr/local/bin/websockify /usr/local/bin/websockify
COPY --from=builder /Core-current.iso /Core-current.iso

# Install only necessary runtime packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        qemu-system-x86 \
        x11-utils \
        xvfb && \
    rm -rf /var/lib/apt/lists/*

# Expose ports
EXPOSE 6080 5901

# Entrypoint to start the services
CMD ["sh", "-c", " \
    Xvfb :1 -screen 0 1024x768x16 & \
    websockify --web=${NO_VNC_HOME} ${VNC_PORT} localhost:${VNC_PORT} & \
    qemu-system-x86_64 -m ${VM_MEMORY} -smp ${VM_CPUS} -nographic -vnc :1 -cdrom /Core-current.iso -boot d && \
    noVNC --listen 6080 --vnc localhost:${VNC_PORT}"]
