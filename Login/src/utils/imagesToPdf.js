// Turns photos of answer sheets into ONE PDF (one photo per A4 page), fully in the browser.
// Photos are shrunk first so the PDF stays under the server's size limit.

const A4_W = 210; // mm
const A4_H = 297;

async function loadBitmap(file) {
    if (typeof createImageBitmap === "function") {
        try { return await createImageBitmap(file); } catch { /* fall through to <img> */ }
    }
    const url = URL.createObjectURL(file);
    try {
        return await new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => resolve(img);
            img.onerror = () => reject(new Error(`${file.name || "Photo"} could not be read. Use a JPG or PNG photo.`));
            img.src = url;
        });
    } finally {
        URL.revokeObjectURL(url);
    }
}

async function toJpeg(file, maxSide, quality) {
    const bmp = await loadBitmap(file);
    const w0 = bmp.width || bmp.naturalWidth;
    const h0 = bmp.height || bmp.naturalHeight;
    const scale = Math.min(1, maxSide / Math.max(w0, h0));
    const w = Math.round(w0 * scale);
    const h = Math.round(h0 * scale);
    const canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "#fff";
    ctx.fillRect(0, 0, w, h);
    ctx.drawImage(bmp, 0, 0, w, h);
    if (bmp.close) bmp.close();
    return { dataUrl: canvas.toDataURL("image/jpeg", quality), w, h };
}

/** files: image Files in page order. Returns a PDF Blob no bigger than maxBytes (or throws). */
export async function imagesToPdf(files, maxBytes = 9.5 * 1024 * 1024) {
    const { jsPDF } = await import("jspdf");
    const attempts = [[1800, 0.85], [1500, 0.75], [1200, 0.65], [1000, 0.5]];

    for (const [maxSide, quality] of attempts) {
        const pdf = new jsPDF({ unit: "mm", format: "a4", compress: true });
        for (let i = 0; i < files.length; i++) {
            const { dataUrl, w, h } = await toJpeg(files[i], maxSide, quality);
            if (i > 0) pdf.addPage();
            const r = Math.min(A4_W / w, A4_H / h);
            const dw = w * r;
            const dh = h * r;
            pdf.addImage(dataUrl, "JPEG", (A4_W - dw) / 2, (A4_H - dh) / 2, dw, dh);
        }
        const blob = pdf.output("blob");
        if (blob.size <= maxBytes) return blob;
    }
    throw new Error("The photos are too large to fit in one PDF. Remove a few pages and try again.");
}
