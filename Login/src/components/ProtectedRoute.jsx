import { Navigate } from "react-router-dom";
import { getToken, getStoredUser, homePath } from "../utils/auth";

/** roles: optional array, e.g. ["admin"]. Wrong role is sent to its own home. */
function ProtectedRoute({ children, roles }) {
    const token = getToken();
    const user = getStoredUser();

    if (!token || !user) return <Navigate to="/login" replace />;

    if (roles && !roles.includes(user.role)) {
        return <Navigate to={homePath(user.role)} replace />;
    }
    return children;
}

export default ProtectedRoute;
