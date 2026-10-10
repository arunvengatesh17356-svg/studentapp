import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { coursesApi, paymentsApi } from "../../services/api";
import { Alert, Button, formatDate, formatPrice } from "../../components/ui";

function loadRazorpay() {
    return new Promise((resolve) => {
        if (window.Razorpay) return resolve(true);
        const s = document.createElement("script");
        s.src = "https://checkout.razorpay.com/v1/checkout.js";
        s.onload = () => resolve(true);
        s.onerror = () => resolve(false);
        document.body.appendChild(s);
    });
}

function CourseDetail() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [data, setData] = useState(null);
    const [batchId, setBatchId] = useState("");
    const [error, setError] = useState("");
    const [paying, setPaying] = useState(false);

    useEffect(() => {
        coursesApi.get(id).then(setData).catch((e) => setError(e.message));
    }, [id]);

    if (error && !data) return <Alert>{error}</Alert>;
    if (!data) return <p>Loading...</p>;

    const { course, batches, purchased } = data;
    const needsBatch = batches.length > 0;

    const buy = async () => {
        setError("");
        if (needsBatch && !batchId) return setError("Please select a batch");
        setPaying(true);
        try {
            const order = await paymentsApi.createOrder({ course_id: course.id, batch_id: batchId || null });

            if (order.free) return navigate("/my-courses");

            if (!(await loadRazorpay())) throw new Error("Could not load Razorpay. Check your internet connection.");

            const rzp = new window.Razorpay({
                key: order.key_id,
                amount: order.amount,
                currency: order.currency,
                name: "TAF IAS Academy",
                description: order.course_name,
                order_id: order.order_id,
                prefill: { name: order.user.name, email: order.user.email },
                theme: { color: "#1e3a8a" },
                handler: async (resp) => {
                    try {
                        await paymentsApi.verify(resp);
                        navigate("/my-courses");
                    } catch (err) {
                        setError(err.message);
                        setPaying(false);
                    }
                },
                modal: { ondismiss: () => setPaying(false) },
            });
            rzp.on("payment.failed", (r) => {
                setError(r.error?.description || "Payment failed");
                setPaying(false);
            });
            rzp.open();
        } catch (err) {
            setError(err.message);
            setPaying(false);
        }
    };

    return (
        <div className="max-w-3xl">
            <Link to="/courses" className="text-blue-700 text-sm">← Back to courses</Link>
            <div className="bg-white rounded-xl shadow overflow-hidden mt-3">
                {course.image_url && <img src={course.image_url} alt="" className="h-56 w-full object-cover" />}
                <div className="p-6">
                    <h1 className="text-3xl font-bold text-blue-900">{course.course_name}</h1>
                    <div className="flex gap-6 text-gray-600 mt-2">
                        {course.duration && <span>Duration: {course.duration}</span>}
                        <span className="font-bold text-gray-900 text-xl">{formatPrice(course.price)}</span>
                    </div>
                    <p className="mt-4 text-gray-700 whitespace-pre-line">{course.description || "No description yet."}</p>

                    <h2 className="font-semibold text-lg mt-6 mb-2">Batches</h2>
                    {!needsBatch && <p className="text-gray-500 text-sm">No batches scheduled yet.</p>}
                    <div className="space-y-2">
                        {batches.map((b) => {
                            const full = b.seats_left === 0;
                            return (
                                <label key={b.id} className={`flex items-center gap-3 border rounded-lg p-3 ${full ? "opacity-50" : "cursor-pointer hover:bg-gray-50"} ${String(batchId) === String(b.id) ? "border-blue-600 bg-blue-50" : ""}`}>
                                    {!purchased && (
                                        <input type="radio" name="batch" disabled={full} checked={String(batchId) === String(b.id)} onChange={() => setBatchId(b.id)} />
                                    )}
                                    <div className="flex-1">
                                        <p className="font-medium">{b.batch_name}</p>
                                        <p className="text-sm text-gray-500">{formatDate(b.start_date)} → {formatDate(b.end_date)}</p>
                                    </div>
                                    <span className="text-sm">{full ? "Full" : `${b.seats_left} seats left`}</span>
                                </label>
                            );
                        })}
                    </div>

                    <div className="mt-6">
                        <Alert>{error}</Alert>
                        {purchased ? (
                            <Link to="/my-courses" className="inline-block bg-green-600 text-white px-5 py-2.5 rounded-lg font-semibold">
                                Already purchased — go to My Courses
                            </Link>
                        ) : (
                            <Button onClick={buy} disabled={paying} className="!px-6 !py-3">
                                {paying ? "Processing..." : Number(course.price) > 0 ? `Buy now — ${formatPrice(course.price)}` : "Enrol for free"}
                            </Button>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

export default CourseDetail;
