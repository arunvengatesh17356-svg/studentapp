import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { paymentsApi } from "../../services/api";
import { Alert, PageHeader, formatDate } from "../../components/ui";

function MyCourses() {
    const [courses, setCourses] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");

    useEffect(() => {
        paymentsApi.myCourses().then((d) => setCourses(d.courses)).catch((e) => setError(e.message)).finally(() => setLoading(false));
    }, []);

    return (
        <div>
            <PageHeader title="My Courses" />
            <Alert>{error}</Alert>
            {loading && <p>Loading...</p>}
            {!loading && courses.length === 0 && (
                <p className="text-gray-500">You haven't purchased any course yet. <Link to="/courses" className="text-blue-700 font-semibold">Browse courses</Link></p>
            )}
            <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
                {courses.map((c) => (
                    <div key={c.purchase_id} className="bg-white rounded-xl shadow overflow-hidden">
                        {c.image_url ? <img src={c.image_url} alt="" className="h-36 w-full object-cover" /> : <div className="h-36 bg-gradient-to-br from-blue-900 to-blue-500" />}
                        <div className="p-4">
                            <h3 className="font-bold text-blue-900">{c.course_name}</h3>
                            {c.batch_name && (
                                <p className="text-sm mt-1">Batch: <b>{c.batch_name}</b><br />
                                    <span className="text-gray-500">{formatDate(c.start_date)} → {formatDate(c.end_date)}</span></p>
                            )}
                            <p className="text-xs text-gray-500 mt-2">Purchased {c.purchased_at?.slice(0, 10)} · ₹{Number(c.amount).toLocaleString("en-IN")}</p>
                            <Link to={`/courses/${c.course_id}`} className="text-blue-700 text-sm font-semibold mt-2 inline-block">View details</Link>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}

export default MyCourses;
